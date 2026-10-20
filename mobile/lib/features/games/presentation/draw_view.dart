import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';
import 'game_common.dart';

const _palette = [0xFFFFFFFF, 0xFFFF5CA8, 0xFF7C5CFF, 0xFF3DDCFF, 0xFF4BE3A4, 0xFFFFC75C, 0xFFFF5C6C];

class DrawView extends ConsumerStatefulWidget {
  const DrawView({super.key, required this.g});
  final GameView g;
  @override
  ConsumerState<DrawView> createState() => _DrawViewState();
}

class _DrawViewState extends ConsumerState<DrawView> {
  final _guess = TextEditingController();
  int _color = _palette[1];
  double _width = 6;
  final List<double> _live = [];
  Timer? _flush;
  Timer? _clock;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _flush?.cancel();
    _clock?.cancel();
    _guess.dispose();
    super.dispose();
  }

  GamesController get _ctrl => ref.read(gamesControllerProvider.notifier);
  bool get _canDraw => widget.g.data['drawer'] == widget.g.you && widget.g.data['phase'] == 'drawing';

  void _start(Offset p, Size s) {
    if (!_canDraw) return;
    _live
      ..clear()
      ..addAll([p.dx / s.width, p.dy / s.height]);
    _flush ??= Timer.periodic(const Duration(milliseconds: 120), (_) => _send(keepTail: true));
    setState(() {});
  }

  void _move(Offset p, Size s) {
    if (!_canDraw || _live.isEmpty) return;
    _live.addAll([(p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0)]);
    if (_live.length >= 380) _send(keepTail: true);
    setState(() {});
  }

  void _end() {
    _send(keepTail: false);
    _flush?.cancel();
    _flush = null;
  }

  /// Streams the in-progress stroke in chunks so the guesser sees it live.
  void _send({required bool keepTail}) {
    if (_live.length < 4 && !(keepTail == false && _live.length == 2)) return;
    final pts = _live.length == 2 ? [..._live, _live[0] + 0.001, _live[1] + 0.001] : List<double>.of(_live);
    _ctrl.sendStroke(DrawStroke(_color, _width, pts));
    final tail = _live.sublist(_live.length - 2);
    _live
      ..clear()
      ..addAll(keepTail ? tail : const []);
    if (mounted) setState(() {});
  }

  Future<void> _submitGuess() async {
    final t = _guess.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _ctrl.act({'type': 'guess', 'text': t});
      _guess.clear();
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = widget.g;
    final d = g.data;
    final drawer = d['drawer'] == g.you;
    final phase = d['phase'] as String;
    final endsAt = DateTime.fromMillisecondsSinceEpoch((d['endsAt'] as num).toInt());
    final total = ((d['seconds'] as num?) ?? 75).toInt();
    final left = endsAt.difference(g.serverNow()).inMilliseconds / 1000;
    final strokes = [for (final s in (d['strokes'] as List?) ?? const []) DrawStroke.fromJson(Map<String, dynamic>.from(s as Map))];
    final guesses = [for (final x in (d['guesses'] as List?) ?? const []) Map<String, dynamic>.from(x as Map)];
    final word = d['word'];
    final hint = bi(context, d['hint']).split('').join(' ');

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text(l.drawRound('${d['round']}', '${d['rounds']}'), style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: phase == 'drawing' ? (left / total).clamp(0.0, 1.0) : 0,
                minHeight: 6,
                backgroundColor: AppColors.surfaceHigh,
                color: left < 15 ? AppColors.danger : AppColors.mint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 30, child: Text(phase == 'drawing' ? '${left.ceil().clamp(0, total)}' : '–', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey('$phase-${d['round']}-${word != null}'),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: phase == 'reveal' ? (d['solved'] == true ? AppColors.primaryGradient : AppColors.warmGradient) : null,
            color: phase == 'reveal' ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.stroke),
          ),
          child: Row(children: [
            Text(phase == 'reveal' ? (d['solved'] == true ? '🎉' : '⏰') : drawer ? '✏️' : '🤔', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: phase == 'reveal'
                  ? Text(
                      '${d['solved'] == true ? l.drawCorrect(drawer ? g.peer.nickname : l.you) : l.drawTimeUp}  ${l.drawAnswer(bi(context, word))}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : drawer
                      ? Text.rich(TextSpan(children: [
                          TextSpan(text: '${l.drawYourWord}: ', style: const TextStyle(color: AppColors.textMuted)),
                          TextSpan(text: bi(context, word).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.amber)),
                        ]))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.drawGuessHint(g.peer.nickname), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Text(hint, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
                        ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, box) {
                final size = box.biggest;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GestureDetector(
                    key: const Key('draw-canvas'),
                    onPanStart: (e) => _start(e.localPosition, size),
                    onPanUpdate: (e) => _move(e.localPosition, size),
                    onPanEnd: (_) => _end(),
                    child: CustomPaint(
                      painter: _CanvasPainter(strokes: strokes, live: _live.length >= 2 ? DrawStroke(_color, _width, List.of(_live)) : null),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (drawer && phase == 'drawing')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _color == c ? 30 : 24,
                  height: _color == c ? 30 : 24,
                  decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: _color == c ? 3 : 1)),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: '${_width.round()}',
              onPressed: () => setState(() => _width = _width == 6 ? 14 : _width == 14 ? 3 : 6),
              icon: Icon(Icons.circle, size: 8 + _width),
            ),
            IconButton(tooltip: l.drawClear, onPressed: () => _ctrl.act({'type': 'clear'}), icon: const Icon(Icons.delete_sweep_rounded)),
          ]),
        )
      else ...[
        if (guesses.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final x in guesses.reversed)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: x['correct'] == true ? AppColors.mint.withValues(alpha: 0.25) : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(x['correct'] == true ? '✓' : x['text'] as String, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
        if (!drawer && phase == 'drawing')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('draw-guess'),
                  controller: _guess,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitGuess(),
                  decoration: InputDecoration(hintText: l.drawGuessPlaceholder, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _sending ? null : _submitGuess, icon: const Icon(Icons.send_rounded)),
            ]),
          )
        else if (drawer)
          const SizedBox(height: 12)
        else
          Padding(padding: const EdgeInsets.all(12), child: Text(l.drawPeerDrawing(g.peer.nickname), style: const TextStyle(color: AppColors.textMuted))),
      ],
    ]);
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({required this.strokes, this.live});
  final List<DrawStroke> strokes;
  final DrawStroke? live;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1C1633));
    // faint dot grid
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var x = 0.05; x < 1; x += 0.1) {
      for (var y = 0.05; y < 1; y += 0.1) {
        canvas.drawCircle(Offset(x * size.width, y * size.height), 1.4, dot);
      }
    }
    for (final s in [...strokes, ?live]) {
      if (s.points.length < 4) continue;
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width * size.width / 360
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(s.points[0] * size.width, s.points[1] * size.height);
      for (var i = 2; i + 1 < s.points.length; i += 2) {
        path.lineTo(s.points[i] * size.width, s.points[i + 1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => true;
}
