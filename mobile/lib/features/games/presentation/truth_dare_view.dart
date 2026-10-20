import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';
import 'game_common.dart';

class TruthDareView extends ConsumerStatefulWidget {
  const TruthDareView({super.key, required this.g});
  final GameView g;
  @override
  ConsumerState<TruthDareView> createState() => _TruthDareViewState();
}

class _TruthDareViewState extends ConsumerState<TruthDareView> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  double _from = 0;
  double _to = 0;
  int _seenSpin = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seenSpin = (widget.g.data['spin'] as num?)?.toInt() ?? 0;
    _to = _angleFor(widget.g.data['choice'] as String?);
    _from = _to;
    _spin.value = 1;
  }

  /// Wheel top half = truth, bottom half = dare; pointer is at the top.
  double _angleFor(String? choice) => choice == 'dare' ? math.pi : 0;

  @override
  void didUpdateWidget(TruthDareView old) {
    super.didUpdateWidget(old);
    final spin = (widget.g.data['spin'] as num?)?.toInt() ?? 0;
    if (spin != _seenSpin) {
      _seenSpin = spin;
      final current = _from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value);
      _from = current % (math.pi * 2);
      // 4 full turns + land on the chosen half with a little wobble offset.
      _to = (math.pi * 2) * 4 + _angleFor(widget.g.data['choice'] as String?) + (spin.isEven ? 0.35 : -0.35);
      _spin.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _act(Map<String, dynamic> a) async {
    setState(() => _busy = true);
    try {
      await ref.read(gamesControllerProvider.notifier).act(a);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = widget.g;
    final d = g.data;
    final phase = d['phase'] as String;
    final choice = d['choice'] as String?;
    final mine = g.myTurn;
    final turnName = mine ? l.you : g.peer.nickname;
    return LayoutBuilder(builder: (context, box) {
      final wheel = math.min(box.maxWidth * 0.62, box.maxHeight * 0.38);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(children: [
          Text(l.tdRound('${d['round']}', '${d['rounds']}'), style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: wheel,
            height: wheel + 18,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: 14,
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, _) => Transform.rotate(
                    angle: -(_from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value)),
                    child: CustomPaint(size: Size.square(wheel), painter: _WheelPainter(truth: l.tdTruth, dare: l.tdDare)),
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded, size: 46, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
            ]),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: FadeTransition(opacity: a, child: c)),
            child: phase == 'prompt' && d['prompt'] != null
                ? AnimatedBuilder(
                    key: ValueKey('p${d['spin']}'),
                    animation: _spin,
                    builder: (_, child) => Opacity(opacity: _spin.value < 0.85 ? 0 : 1, child: child),
                    child: _PromptCard(choice: choice ?? 'truth', text: bi(context, d['prompt']), who: turnName),
                  )
                : Padding(
                    key: const ValueKey('choose'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(mine ? l.tdChoose : l.tdWaiting(g.peer.nickname), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
          ),
          const SizedBox(height: 18),
          if (mine && !g.ended && phase == 'choose')
            Row(children: [
              Expanded(child: GradientButton(key: const Key('td-truth'), label: l.tdTruth, gradient: AppColors.coolGradient, loading: _busy, onPressed: () => _act({'type': 'pick', 'choice': 'truth'}))),
              const SizedBox(width: 10),
              Expanded(child: GradientButton(key: const Key('td-dare'), label: l.tdDare, gradient: AppColors.warmGradient, loading: _busy, onPressed: () => _act({'type': 'pick', 'choice': 'dare'}))),
            ]),
          if (mine && !g.ended && phase == 'choose') ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _busy ? null : () => _act({'type': 'pick', 'choice': 'random'}), icon: const Icon(Icons.casino_rounded), label: Text(l.tdSpin)),
          ],
          if (mine && !g.ended && phase == 'prompt')
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _act({'type': 'skip'}), child: Text(l.tdSkip))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GradientButton(key: const Key('td-done'), label: l.tdDone, loading: _busy, onPressed: () => _act({'type': 'done'}))),
            ]),
          if (!mine && phase == 'prompt') Text(l.tdAnswering(g.peer.nickname), style: const TextStyle(color: AppColors.textMuted)),
        ]),
      );
    });
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.choice, required this.text, required this.who});
  final String choice;
  final String text;
  final String who;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final truth = choice == 'truth';
    return Container(
      key: const Key('td-prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: truth ? AppColors.coolGradient : AppColors.warmGradient,
        boxShadow: [BoxShadow(color: (truth ? AppColors.cyan : AppColors.pink).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
            child: Text((truth ? l.tdTruth : l.tdDare).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
          ),
          const Spacer(),
          Text(who, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
      ]),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.truth, required this.dare});
  final String truth;
  final String dare;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    // 8 slices alternating truth / dare, truth centred at the top.
    const slices = 8;
    const sweep = math.pi * 2 / slices;
    for (var i = 0; i < slices; i++) {
      final isTruth = i < 2 || i >= 6;
      final start = -math.pi / 2 - sweep + i * sweep;
      canvas.drawArc(rect, start, sweep, true, Paint()
        ..shader = (isTruth ? AppColors.coolGradient : AppColors.warmGradient).createShader(rect)
        ..color = Colors.white);
      canvas.drawArc(rect, start, sweep, true, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.bg.withValues(alpha: 0.6));
    }
    void label(String t, double angle) {
      final tp = TextPainter(
        text: TextSpan(text: t.toUpperCase(), style: TextStyle(fontSize: r * 0.16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      tp.paint(canvas, Offset(-tp.width / 2, -r * 0.62));
      canvas.restore();
    }

    label(truth, 0);
    label(dare, math.pi);
    canvas.drawCircle(c, r * 0.16, Paint()..color = AppColors.bg);
    canvas.drawCircle(c, r * 0.1, Paint()..shader = AppColors.primaryGradient.createShader(Rect.fromCircle(center: c, radius: r * 0.1)));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.truth != truth || old.dare != dare;
}
