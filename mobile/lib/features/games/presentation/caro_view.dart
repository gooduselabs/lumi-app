import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';

/// 15×15 gomoku board. Moves are only *requested* here; the server validates and broadcasts.
class CaroView extends ConsumerStatefulWidget {
  const CaroView({super.key, required this.g});
  final GameView g;
  @override
  ConsumerState<CaroView> createState() => _CaroViewState();
}

class _CaroViewState extends ConsumerState<CaroView> {
  int? _pending;

  Future<void> _tap(int cell) async {
    final g = widget.g;
    final board = (g.data['board'] as List).cast<String>();
    if (!g.myTurn || g.ended || board[cell].isNotEmpty || _pending != null) return;
    setState(() => _pending = cell);
    try {
      await ref.read(gamesControllerProvider.notifier).act({'type': 'place', 'cell': cell});
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final size = (g.data['size'] as num).toInt();
    final board = (g.data['board'] as List).cast<String>();
    final last = (g.data['last'] as num?)?.toInt();
    final winLine = ((g.data['winLine'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    final myMark = g.data['x'] == g.you ? 'X' : 'O';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(context.l10n.caroYouAre(''), style: const TextStyle(color: AppColors.textMuted)),
          _Mark(mark: myMark, size: 18),
        ]),
      ),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.stroke),
                boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.12), blurRadius: 30)],
              ),
              padding: const EdgeInsets.all(6),
              child: InteractiveViewer(
                maxScale: 3,
                child: LayoutBuilder(builder: (context, box) {
                  final cell = box.maxWidth / size;
                  return GestureDetector(
                    key: const Key('caro-board'),
                    onTapUp: (d) {
                      final c = (d.localPosition.dx / cell).floor().clamp(0, size - 1);
                      final r = (d.localPosition.dy / cell).floor().clamp(0, size - 1);
                      _tap(r * size + c);
                    },
                    child: CustomPaint(
                      painter: _GridPainter(size),
                      child: Stack(children: [
                        for (var i = 0; i < board.length; i++)
                          if (board[i].isNotEmpty || i == _pending)
                            Positioned(
                              left: (i % size) * cell,
                              top: (i ~/ size) * cell,
                              width: cell,
                              height: cell,
                              child: _Cell(
                                key: ValueKey('c$i'),
                                mark: board[i].isNotEmpty ? board[i] : myMark,
                                ghost: board[i].isEmpty,
                                last: i == last,
                                win: winLine.contains(i),
                              ),
                            ),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.n);
  final int n;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final step = size.width / n;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), p);
      canvas.drawLine(Offset(0, i * step), Offset(size.width, i * step), p);
    }
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (final r in [3, 7, 11]) {
      for (final c in [3, 7, 11]) {
        canvas.drawCircle(Offset((c + 0.5) * step, (r + 0.5) * step), 2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.n != n;
}

class _Cell extends StatelessWidget {
  const _Cell({super.key, required this.mark, this.ghost = false, this.last = false, this.win = false});
  final String mark;
  final bool ghost;
  final bool last;
  final bool win;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.2, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: win
                ? (mark == 'X' ? AppColors.pink : AppColors.cyan).withValues(alpha: 0.35)
                : last
                    ? Colors.white.withValues(alpha: 0.08)
                    : null,
            boxShadow: win ? [BoxShadow(color: (mark == 'X' ? AppColors.pink : AppColors.cyan).withValues(alpha: 0.6), blurRadius: 10)] : null,
          ),
          child: Opacity(opacity: ghost ? 0.35 : 1, child: Center(child: _Mark(mark: mark))),
        ),
      );
}

class _Mark extends StatelessWidget {
  const _Mark({required this.mark, this.size});
  final String mark;
  final double? size;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final s = size ?? box.maxWidth * 0.62;
        return Text(
          mark == 'X' ? '✕' : '◯',
          style: TextStyle(
            fontSize: s,
            height: 1,
            fontWeight: FontWeight.w900,
            color: mark == 'X' ? AppColors.pink : AppColors.cyan,
            shadows: [Shadow(color: (mark == 'X' ? AppColors.pink : AppColors.cyan).withValues(alpha: 0.7), blurRadius: 8)],
          ),
        );
      });
}
