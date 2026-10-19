import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../application/match_controller.dart';

final genderPrefProvider = NotifierProvider<GenderPrefController, String>(GenderPrefController.new);

class GenderPrefController extends Notifier<String> {
  @override
  String build() => 'ANY';
  void set(String v) => state = v;
}

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    final stats = ref.watch(matchStatsProvider);
    final pref = ref.watch(genderPrefProvider);

    return GlowBackground(
      intensity: 0.8,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(matchStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(children: [
                LumiAvatar(avatarId: me?.avatarId, size: 46, ring: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.hello(me?.nickname ?? ''), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Row(children: [
                      const _PulseDot(),
                      const SizedBox(width: 6),
                      Text(
                        stats.whenOrNull(data: (s) => l.onlineNow(s.online)) ?? l.connecting,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),
              _ModeCard(
                title: l.soulMatch,
                subtitle: l.soulMatchDesc(3),
                icon: Icons.chat_bubble_rounded,
                gradient: AppColors.primaryGradient,
                avatars: const ['a02', 'a09', 'a14'],
                onTap: () => context.push('/match?mode=soul'),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                title: l.voiceMatch,
                subtitle: l.voiceMatchDesc(7),
                icon: Icons.graphic_eq_rounded,
                gradient: AppColors.coolGradient,
                avatars: const ['a05', 'a19', 'a12'],
                disabled: stats.whenOrNull(data: (s) => !s.voiceEnabled) ?? false,
                disabledText: l.voiceUnavailable,
                onTap: () => context.push('/match?mode=voice'),
              ),
              const SizedBox(height: 22),
              Text(l.matchFilter, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (final (v, label) in [('ANY', l.filterAny), ('FEMALE', l.genderFemale), ('MALE', l.genderMale)])
                  ChoiceChip(
                    label: Text(label),
                    selected: pref == v,
                    onSelected: (_) => ref.read(genderPrefProvider.notifier).set(v),
                  ),
              ]),
              const SizedBox(height: 26),
              Text(l.howItWorks, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(children: [
                  for (final (i, t) in [l.how1, l.how2, l.how3].indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: i < 2 ? 14 : 0),
                      child: Row(children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
                          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Row(children: [
                  const Icon(Icons.shield_moon_outlined, color: AppColors.cyan),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.safetyText, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.avatars,
    required this.onTap,
    this.disabled = false,
    this.disabledText,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final List<String> avatars;
  final VoidCallback onTap;
  final bool disabled;
  final String? disabledText;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GlassCard(
        gradient: gradient,
        onTap: disabled ? () => showSnack(context, disabledText ?? '', error: true) : onTap,
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
          SizedBox(
            width: 84,
            height: 100,
            child: Stack(children: [
              Positioned(top: 0, right: 0, child: LumiAvatar(avatarId: avatars[0], size: 44)),
              Positioned(top: 30, left: 0, child: LumiAvatar(avatarId: avatars[1], size: 50)),
              Positioned(bottom: 0, right: 6, child: LumiAvatar(avatarId: avatars[2], size: 38)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ]),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mint,
            boxShadow: [BoxShadow(color: AppColors.mint.withValues(alpha: 1 - _c.value), blurRadius: 2, spreadRadius: 6 * _c.value)],
          ),
        ),
      );
}
