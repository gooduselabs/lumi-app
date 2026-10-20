import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../application/games_controller.dart';
import '../domain/game_models.dart';
import 'game_common.dart';
import 'game_screen.dart';

class KnowMeView extends ConsumerStatefulWidget {
  const KnowMeView({super.key, required this.g});
  final GameView g;
  @override
  ConsumerState<KnowMeView> createState() => _KnowMeViewState();
}

class _KnowMeViewState extends ConsumerState<KnowMeView> {
  int? _self;
  int? _guess;
  int _forIndex = -1;
  bool _busy = false;

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
    final index = (d['index'] as num).toInt();
    final count = (d['count'] as num).toInt();
    if (_forIndex != index) {
      _forIndex = index;
      _self = null;
      _guess = null;
    }
    final q = Map<String, dynamic>.from(d['question'] as Map);
    final options = [for (final o in q['options'] as List) bi(context, o)];
    final phase = d['phase'] as String;
    final mine = d['mine'] as Map?;
    final answers = d['answers'] as Map?;
    final peer = g.peer;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(l.kmQuestion('${index + 1}', '$count'), style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (index + (phase == 'answer' ? 0 : 1)) / count),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: AppColors.surfaceHigh, color: AppColors.pink),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: Container(
            key: ValueKey('q$index'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(24)),
            child: Text(bi(context, q['q']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.25)),
          ),
        ),
        const SizedBox(height: 18),
        if (phase == 'answer' && mine == null) ...[
          Text(l.kmYourAnswer, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _Options(options: options, selected: _self, onPick: (i) => setState(() => _self = i), color: AppColors.violet, keyPrefix: 'km-self'),
          const SizedBox(height: 16),
          Text(l.kmGuess(peer.nickname), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _Options(options: options, selected: _guess, onPick: (i) => setState(() => _guess = i), color: AppColors.pink, keyPrefix: 'km-guess'),
          const SizedBox(height: 18),
          GradientButton(
            key: const Key('km-submit'),
            label: l.kmSubmit,
            loading: _busy,
            onPressed: _self == null || _guess == null ? null : () => _act({'type': 'answer', 'q': index, 'self': _self, 'guess': _guess}),
          ),
        ] else if (phase == 'answer') ...[
          const SizedBox(height: 30),
          const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6))),
          const SizedBox(height: 14),
          Center(child: Text(l.kmWaiting(peer.nickname), style: const TextStyle(color: AppColors.textMuted))),
        ] else if (answers != null) ...[
          _Reveal(g: g, options: options, answers: answers),
          const SizedBox(height: 18),
          Center(child: CompatRing(percent: (d['compatibility'] as num?)?.toInt() ?? 0, size: 110)),
          const SizedBox(height: 18),
          if (phase == 'reveal')
            GradientButton(
              key: const Key('km-next'),
              label: index + 1 >= count ? l.kmSeeResult : l.kmNext,
              loading: _busy,
              onPressed: () => _act({'type': 'next', 'q': index}),
            ),
        ],
      ]),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.options, required this.selected, required this.onPick, required this.color, required this.keyPrefix});
  final List<String> options;
  final int? selected;
  final ValueChanged<int> onPick;
  final Color color;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            key: Key('$keyPrefix-$i'),
            onTap: () => onPick(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected == i ? color.withValues(alpha: 0.28) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected == i ? color : AppColors.stroke, width: selected == i ? 1.6 : 1),
              ),
              child: Text(options[i], style: TextStyle(fontWeight: selected == i ? FontWeight.w800 : FontWeight.w500)),
            ),
          ),
      ]);
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.g, required this.options, required this.answers});
  final GameView g;
  final List<String> options;
  final Map answers;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = answers[g.you] as Map;
    final peer = answers[g.peer.id] as Map;
    Widget row(String who, String picked, String guessLabel, bool right) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: (right ? AppColors.mint : AppColors.danger).withValues(alpha: 0.6)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(who, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(picked, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(guessLabel, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ]),
              ),
              Icon(right ? Icons.check_circle_rounded : Icons.cancel_rounded, color: right ? AppColors.mint : AppColors.danger, size: 28),
            ]),
          ),
        );
    final peerRight = peer['guess'] == me['self'];
    final meRight = me['guess'] == peer['self'];
    return Column(children: [
      row(l.kmPicked(g.peer.nickname), options[(peer['self'] as num).toInt()], '${l.you}: ${options[(me['guess'] as num).toInt()]} · ${meRight ? l.kmRight : l.kmWrong}', meRight),
      row(l.kmPicked(l.you), options[(me['self'] as num).toInt()], '${g.peer.nickname}: ${options[(peer['guess'] as num).toInt()]} · ${peerRight ? l.kmRight : l.kmWrong}', peerRight),
    ]);
  }
}
