import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../application/match_controller.dart';
import '../domain/match_models.dart';
import 'discover_screen.dart';
import 'voice_call_panel.dart';

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, required this.mode});
  final MatchMode mode;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(matchControllerProvider);
      if (s.phase == MatchPhase.idle || s.phase == MatchPhase.ended || s.phase == MatchPhase.mutual) {
        ref.read(matchControllerProvider.notifier).start(widget.mode, genderPref: ref.read(genderPrefProvider));
      }
    });
  }

  Future<bool> _confirmLeave() async {
    final s = ref.read(matchControllerProvider);
    final ctrl = ref.read(matchControllerProvider.notifier);
    if (s.phase == MatchPhase.searching) {
      await ctrl.cancel();
      return true;
    }
    if (s.phase == MatchPhase.chatting) {
      if (!await confirmDialog(context, context.l10n.skipConfirm, confirm: context.l10n.skip, danger: true)) return false;
      await ctrl.skip();
    }
    ctrl.reset();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider);
    ref.listen(matchControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        showSnack(context, context.l10n.errorText(next.error!), error: true);
        ref.read(matchControllerProvider.notifier).clearError();
        if (next.phase == MatchPhase.idle && context.canPop()) context.pop();
      }
      if (prev?.partnerLiked == false && next.partnerLiked) HapticFeedback.mediumImpact();
      if (next.phase == MatchPhase.mutual && prev?.phase != MatchPhase.mutual) HapticFeedback.heavyImpact();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: GlowBackground(
          intensity: state.phase == MatchPhase.chatting ? 0.4 : 0.9,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: c),
              ),
              child: switch (state.phase) {
                MatchPhase.idle || MatchPhase.searching => _Searching(key: const ValueKey('search'), mode: widget.mode, onCancel: () async {
                    if (await _confirmLeave() && context.mounted) context.pop();
                  }),
                MatchPhase.chatting => state.mode == MatchMode.voice
                    ? _VoiceSession(key: ValueKey('v${state.session!.id}'), state: state, onLeave: _confirmLeave)
                    : _SoulChat(key: ValueKey('c${state.session!.id}'), state: state, onLeave: _confirmLeave),
                MatchPhase.ended => _Ended(key: const ValueKey('ended'), reason: state.endReason ?? EndReason.other, mode: state.mode),
                MatchPhase.mutual => _Mutual(key: const ValueKey('mutual'), state: state),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- searching

class _Searching extends ConsumerStatefulWidget {
  const _Searching({super.key, required this.mode, required this.onCancel});
  final MatchMode mode;
  final VoidCallback onCancel;
  @override
  ConsumerState<_Searching> createState() => _SearchingState();
}

class _SearchingState extends ConsumerState<_Searching> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    const orbit = ['a03', 'a08', 'a13', 'a16', 'a21', 'a24'];
    return Column(children: [
      Align(
        alignment: Alignment.topLeft,
        child: IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close_rounded)),
      ),
      const Spacer(),
      SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: (1 - ((_c.value * 3 + i / 3) % 1)).clamp(0, 1) * 0.6,
                child: Container(
                  width: 120 + 180 * ((_c.value * 3 + i / 3) % 1),
                  height: 120 + 180 * ((_c.value * 3 + i / 3) % 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.mode == MatchMode.voice ? AppColors.cyan : AppColors.pink, width: 2),
                  ),
                ),
              ),
            for (var i = 0; i < orbit.length; i++)
              Transform.translate(
                offset: Offset.fromDirection(_c.value * 2 * math.pi + i * math.pi / 3, 120),
                child: Opacity(opacity: 0.85, child: LumiAvatar(avatarId: orbit[i], size: 36)),
              ),
            LumiAvatar(avatarId: me?.avatarId, size: 96, ring: true),
          ]),
        ),
      ),
      const SizedBox(height: 32),
      Text(l.searching, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(l.searchingHint, style: const TextStyle(color: AppColors.textMuted)),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(24),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          onPressed: widget.onCancel,
          child: Text(l.cancel),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- shared header

class _SessionHeader extends ConsumerWidget {
  const _SessionHeader({required this.state, required this.onLeave});
  final MatchState state;
  final Future<bool> Function() onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = state.session!.partner;
    final ctrl = ref.read(matchControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(children: [
        IconButton(
          onPressed: () async {
            if (await onLeave() && context.mounted) context.pop();
          },
          icon: const Icon(Icons.close_rounded),
        ),
        LumiAvatar(avatarId: p.avatarId, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.stranger, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              [l.genderLabel(p.gender), if (p.age != null) l.ageYears(p.age!)].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
        ),
        Countdown(session: state.session!, onDone: ctrl.localTimeout),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) async {
            if (v == 'report') {
              await showReportSheet(context, ctrl.reportPartner);
            } else if (v == 'block') {
              if (await confirmDialog(context, l.blockConfirm, confirm: l.block, danger: true)) await ctrl.blockPartner();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'report', child: Text(l.report)),
            PopupMenuItem(value: 'block', child: Text(l.block, style: const TextStyle(color: AppColors.danger))),
          ],
        ),
      ]),
    );
  }
}

class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.session, required this.onDone, this.size = 52});
  final MatchSessionInfo session;
  final VoidCallback onDone;
  final double size;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late Timer _t;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_done && widget.session.remaining() <= Duration.zero) {
        _done = true;
        // small grace so the server-side timeout/mutual event usually arrives first
        Future.delayed(const Duration(seconds: 2), () => mounted ? widget.onDone() : null);
      }
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.session.remaining();
    final frac = (rem.inMilliseconds / (widget.session.durationSec * 1000)).clamp(0.0, 1.0);
    final urgent = rem.inSeconds <= 30;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: frac,
          strokeWidth: 3.5,
          backgroundColor: AppColors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(urgent ? AppColors.danger : AppColors.pink),
        ),
        Text(formatCountdown(rem), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: urgent ? AppColors.danger : AppColors.text)),
      ]),
    );
  }
}

class _LikeBar extends ConsumerWidget {
  const _LikeBar({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(matchControllerProvider.notifier);
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
          onPressed: () async {
            if (await confirmDialog(context, l.skipConfirm, confirm: l.skip, danger: true)) await ctrl.skip();
          },
          icon: const Icon(Icons.skip_next_rounded),
          label: Text(l.skip),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: _HeartButton(liked: state.iLiked, onTap: ctrl.like, label: l.like),
      ),
    ]);
  }
}

class _HeartButton extends StatefulWidget {
  const _HeartButton({required this.liked, required this.onTap, required this.label});
  final bool liked;
  final VoidCallback onTap;
  final String label;
  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(scale: 1 + 0.12 * math.sin(_c.value * math.pi), child: child),
      child: GradientButton(
        height: 50,
        label: widget.label,
        icon: widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        gradient: widget.liked ? const LinearGradient(colors: [AppColors.pink, AppColors.pink]) : AppColors.primaryGradient,
        onPressed: widget.liked
            ? null
            : () {
                HapticFeedback.lightImpact();
                _c.forward(from: 0);
                widget.onTap();
              },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = state.partnerLiked ? l.partnerLiked : (state.iLiked ? l.youLiked : null);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(text),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.pink.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
              child: Text(text, style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
    );
  }
}

// ---------------------------------------------------------------- soul chat

class _SoulChat extends ConsumerStatefulWidget {
  const _SoulChat({super.key, required this.state, required this.onLeave});
  final MatchState state;
  final Future<bool> Function() onLeave;
  @override
  ConsumerState<_SoulChat> createState() => _SoulChatState();
}

class _SoulChatState extends ConsumerState<_SoulChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text;
    if (t.trim().isEmpty) return;
    ref.read(matchControllerProvider.notifier).send(t);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = widget.state;
    final p = state.session!.partner;
    final msgs = state.messages.reversed.toList();
    return Column(children: [
      _SessionHeader(state: state, onLeave: widget.onLeave),
      if (p.interests.isNotEmpty)
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final i in p.interests)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InterestChip(keyName: i, highlight: p.common.contains(i)),
                ),
            ],
          ),
        ),
      const Divider(height: 16),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          itemCount: msgs.length + 1,
          itemBuilder: (_, i) {
            if (i == msgs.length) return _IntroCard(partner: p);
            final m = msgs[i];
            return _Bubble(text: m.text, mine: m.mine, key: ValueKey(m.id));
          },
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: state.partnerTyping
            ? Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 6),
                child: Align(alignment: Alignment.centerLeft, child: TypingDots(label: l.partnerTyping)),
              )
            : const SizedBox.shrink(),
      ),
      _StatusPill(state: state),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              maxLength: 500,
              onChanged: (_) => ref.read(matchControllerProvider.notifier).typing(),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(hintText: l.typeMessage, counterText: '', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.violet, fixedSize: const Size(50, 50)),
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: _LikeBar(state: state)),
    ]);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.partner});
  final AnonPartner partner;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(children: [
        LumiAvatar(avatarId: partner.avatarId, size: 72, ring: true),
        const SizedBox(height: 10),
        Text(l.soulIntro, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
        if (partner.bio != null && partner.bio!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('“${partner.bio}”', textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
        if (partner.common.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${l.commonInterests}: ${partner.common.map(l.interest).join(', ')}',
              style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(
        alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
        scale: 0.85 + 0.15 * v,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: mine ? AppColors.primaryGradient : null,
            color: mine ? null : AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
          ),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
        ),
      ),
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.label});
  final String label;
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          children: List.generate(3, (i) {
            final v = math.sin((_c.value * 2 * math.pi) - i * 0.8);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              transform: Matrix4.translationValues(0, -3 * v.clamp(0, 1), 0),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textMuted),
            );
          }),
        ),
      ),
      const SizedBox(width: 8),
      Text(widget.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}

// ---------------------------------------------------------------- voice session

class _VoiceSession extends StatelessWidget {
  const _VoiceSession({super.key, required this.state, required this.onLeave});
  final MatchState state;
  final Future<bool> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SessionHeader(state: state, onLeave: onLeave),
      Expanded(child: VoiceCallPanel(session: state.session!)),
      _StatusPill(state: state),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: _LikeBar(state: state)),
    ]);
  }
}

// ---------------------------------------------------------------- ended / mutual

class _Ended extends ConsumerWidget {
  const _Ended({super.key, required this.reason, required this.mode});
  final EndReason reason;
  final MatchMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final (emoji, title) = switch (reason) {
      EndReason.timeout => ('⏳', l.endedTimeout),
      EndReason.skippedByPartner => ('👋', l.endedPartnerSkipped),
      EndReason.partnerLeft => ('📡', l.endedPartnerLeft),
      EndReason.blocked => ('🛡️', l.endedBlocked),
      _ => ('🌙', l.endedSkipped),
    };
    final ctrl = ref.read(matchControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        EmptyView(emoji: emoji, title: title, subtitle: l.endedHint),
        const Spacer(),
        GradientButton(
          label: l.findAnother,
          icon: Icons.refresh_rounded,
          onPressed: () => ctrl.start(mode, genderPref: ref.read(genderPrefProvider)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            ctrl.reset();
            context.pop();
          },
          child: Text(l.backHome),
        ),
      ]),
    );
  }
}

class _Mutual extends ConsumerStatefulWidget {
  const _Mutual({super.key, required this.state});
  final MatchState state;
  @override
  ConsumerState<_Mutual> createState() => _MutualState();
}

class _MutualState extends ConsumerState<_Mutual> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  final _rnd = math.Random(7);
  late final _hearts = List.generate(18, (_) => (_rnd.nextDouble(), _rnd.nextDouble(), 14 + _rnd.nextDouble() * 18));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    final friend = widget.state.friend!;
    return Stack(children: [
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _HeartsPainter(_hearts, _c.value)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          SizedBox(
            height: 130,
            child: Stack(alignment: Alignment.center, children: [
              Transform.translate(offset: const Offset(-48, 0), child: LumiAvatar(avatarId: me?.avatarId, size: 110, ring: true)),
              Transform.translate(offset: const Offset(48, 0), child: LumiAvatar(avatarId: friend.avatarId, size: 110, ring: true)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
                child: const Icon(Icons.favorite_rounded, color: AppColors.pink, size: 32),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
            child: Text(l.mutualTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 10),
          Text(l.mutualSubtitle(friend.nickname), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const Spacer(),
          GradientButton(
            label: l.sayHi,
            icon: Icons.chat_rounded,
            onPressed: () {
              final id = widget.state.conversationId!;
              ref.read(matchControllerProvider.notifier).reset();
              context.pushReplacement('/chat/$id');
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(matchControllerProvider.notifier).reset();
              context.pop();
            },
            child: Text(l.backHome),
          ),
        ]),
      ),
    ]);
  }
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter(this.items, this.t);
  final List<(double, double, double)> items;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, phase, s) in items) {
      final p = (t + phase) % 1;
      final dx = x * size.width + math.sin(p * 2 * math.pi) * 16;
      final dy = size.height * (1 - p);
      final tp = TextPainter(
        text: TextSpan(text: '♥', style: TextStyle(fontSize: s, color: Color.lerp(AppColors.pink, AppColors.violet, x)!.withValues(alpha: (1 - p) * 0.7))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.t != t;
}
