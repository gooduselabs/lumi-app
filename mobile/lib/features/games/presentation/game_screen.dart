import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';
import 'caro_view.dart';
import 'draw_view.dart';
import 'game_common.dart';
import 'know_me_view.dart';
import 'truth_dare_view.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  Future<void> _exit(BuildContext context, WidgetRef ref, GameView g) async {
    final l = context.l10n;
    if (!g.ended) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.gameLeave),
          content: Text(l.gameLeaveConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.gameLeave)),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(gamesControllerProvider.notifier).leave();
    }
    ref.read(gamesControllerProvider.notifier).close();
    if (context.mounted) context.canPop() ? context.pop() : context.go('/chat/${g.conversationId}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(gamesControllerProvider);
    final g = st.game;
    if (g == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit(context, ref, g);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => _exit(context, ref, g)),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(g.kind.emoji),
            const SizedBox(width: 8),
            Text(g.kind.title(l)),
          ]),
          centerTitle: true,
        ),
        body: GlowBackground(
          intensity: 0.5,
          child: SafeArea(
            top: false,
            child: Stack(children: [
              Column(children: [
                _Header(g: g),
                if (!g.peerOnline)
                  Container(
                    width: double.infinity,
                    color: AppColors.amber.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(6),
                    child: Text(l.gamePeerOffline(g.peer.nickname), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.amber, fontSize: 12)),
                  ),
                Expanded(
                  child: switch (g.kind) {
                    GameKind.caro => CaroView(g: g),
                    GameKind.truthDare => TruthDareView(g: g),
                    GameKind.knowMe => KnowMeView(g: g),
                    GameKind.draw => DrawView(g: g),
                  },
                ),
              ]),
              if (g.ended && g.result != null)
                _ResultOverlay(g: g, rematchAsked: st.rematchAsked, onExit: () => _exit(context, ref, g)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.g});
  final GameView g;

  int? _score(String id) {
    final s = g.data['scores'];
    if (s is Map && s[id] is num) return (s[id] as num).toInt();
    final st = g.data['stats'];
    if (st is Map && st[id] is Map) return ((st[id] as Map)['done'] as num?)?.toInt();
    final c = g.data['correct'];
    if (c is Map && c[id] is num) return (c[id] as num).toInt();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget side(GamePlayer p, {required bool right}) {
      final active = g.turn == p.id;
      final score = _score(p.id);
      final children = [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active ? AppColors.primaryGradient : null,
            boxShadow: active ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 14)] : null,
          ),
          child: LumiAvatar(avatarId: p.avatarId, size: 42),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            Text(p.id == g.you ? '${p.nickname} (${l.you})' : p.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (score != null)
              TweenAnimationBuilder<double>(
                tween: Tween(end: score.toDouble()),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, _) => Text('${v.round()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.amber)),
              ),
          ]),
        ),
      ];
      return Expanded(child: Row(mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start, children: right ? children.reversed.toList() : children));
    }

    final turnText = g.ended
        ? ''
        : g.turn == null
            ? ''
            : g.myTurn
                ? l.gameYourTurn
                : l.gamePeerTurn(g.peer.nickname);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(children: [
        Row(children: [side(g.me, right: false), const Text('VS', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w900)), side(g.peer, right: true)]),
        if (turnText.isNotEmpty) ...[const SizedBox(height: 8), TurnPill(text: turnText, active: g.myTurn)],
      ]),
    );
  }
}

class _ResultOverlay extends ConsumerStatefulWidget {
  const _ResultOverlay({required this.g, required this.rematchAsked, required this.onExit});
  final GameView g;
  final bool rematchAsked;
  final VoidCallback onExit;
  @override
  ConsumerState<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends ConsumerState<_ResultOverlay> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = widget.g;
    final r = g.result!;
    final won = r.winnerId == g.you;
    final iAsked = g.rematch.contains(g.you);
    final peerAsked = widget.rematchAsked || g.rematch.contains(g.peer.id);
    final headline = outcomeText(l, r, meId: g.you, peerName: g.peer.nickname);
    return Positioned.fill(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.2)),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Stack(children: [
            if (won || (r.compatibility ?? 0) >= 60) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_c)))),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _c, curve: const Interval(0, 0.35, curve: Curves.elasticOut)),
                child: Container(
                  key: const Key('game-result'),
                  margin: const EdgeInsets.all(28),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.stroke),
                    boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.35), blurRadius: 40)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (r.kind == GameKind.knowMe && r.compatibility != null)
                      CompatRing(percent: r.compatibility!, size: 150)
                    else
                      Text(won ? '🏆' : r.winnerId == null ? '🤝' : '💫', style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 14),
                    Text(
                      r.kind == GameKind.knowMe && r.compatibility != null ? compatTier(l, r.compatibility!) : headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final p in [g.me, g.peer]) ...[
                        LumiAvatar(avatarId: p.avatarId, size: 30),
                        const SizedBox(width: 6),
                        Text('${r.scores[p.id] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        if (p == g.me) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('–', style: TextStyle(color: AppColors.textFaint))),
                      ],
                    ]),
                    if (peerAsked && !iAsked) ...[
                      const SizedBox(height: 12),
                      Text(l.gameRematchAsked(g.peer.nickname), style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      key: const Key('game-rematch'),
                      label: iAsked ? l.gameRematchWaiting(g.peer.nickname) : l.gameRematch,
                      icon: Icons.replay_rounded,
                      loading: _busy,
                      onPressed: iAsked
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await ref.read(gamesControllerProvider.notifier).rematch();
                              } catch (e) {
                                if (context.mounted) showSnack(context, context.l10n.errorText(e), error: true);
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: widget.onExit, child: Text(l.gameBackToChat)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Animated compatibility ring (used in Who-Knows-Who and the result card).
class CompatRing extends StatelessWidget {
  const CompatRing({super.key, required this.percent, this.size = 120});
  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent / 100),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(v * 100).round()}%', style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w900)),
                Text(context.l10n.kmCompat, style: TextStyle(fontSize: size * 0.08, color: AppColors.textMuted)),
              ]),
            ),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()
      ..shader = const SweepGradient(colors: [AppColors.violet, AppColors.pink, AppColors.amber, AppColors.violet]).createShader(r)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;
  static final _rnd = math.Random(7);
  static final _bits = List.generate(70, (_) => (_rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextInt(5)));
  static const _colors = [AppColors.pink, AppColors.violet, AppColors.amber, AppColors.cyan, AppColors.mint];

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final (x, delay, spin, c) in _bits) {
      final p = ((t - delay * 0.4) / 0.8).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final dx = x * size.width + math.sin((p + spin) * 8) * 18;
      final dy = -20 + p * (size.height + 40);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate((p + spin) * 10);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)),
          Paint()..color = _colors[c].withValues(alpha: 1 - p * 0.6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
