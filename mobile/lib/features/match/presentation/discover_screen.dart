import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/location/location_service.dart';
import '../../nearby/application/nearby_controller.dart';
import '../../nearby/presentation/filter_widgets.dart';
import '../application/match_controller.dart';

final genderPrefProvider = NotifierProvider<GenderPrefController, String>(GenderPrefController.new);

class GenderPrefController extends Notifier<String> {
  @override
  String build() => 'ANY';
  void set(String v) => state = v;
}

/// "Prefer nearby" for Soul/Voice Match (requires a shared, non-hidden location).
final preferNearbyProvider = NotifierProvider<PreferNearbyController, bool>(PreferNearbyController.new);

class PreferNearbyController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  Future<void> _togglePreferNearby(BuildContext context, WidgetRef ref, bool v) async {
    final me = ref.read(meProvider);
    if (v && (me == null || !me.hasLocation || me.locationHidden)) {
      try {
        await ref.read(locationActionsProvider).share();
      } catch (e) {
        if (context.mounted) showLocationError(context, e, ref.read(locationServiceProvider));
        return;
      }
    }
    ref.read(preferNearbyProvider.notifier).set(v);
  }

  Future<void> _saveAge(BuildContext context, WidgetRef ref, int min, int max) async {
    try {
      await ref.read(locationActionsProvider).setAgeRange(min, max);
    } catch (e) {
      if (context.mounted) showSnack(context, context.l10n.errorText(e), error: true);
    }
  }

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
              const SizedBox(height: 14),
              _NearbyCard(onTap: () => context.push('/nearby')),
              const SizedBox(height: 22),
              Text(l.filters, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GlassCard(
                key: const Key('discoverFilters'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.genderFilter, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GenderChips(value: pref, onChanged: (v) => ref.read(genderPrefProvider.notifier).set(v)),
                  const SizedBox(height: 14),
                  AgeRangeField(
                    min: me?.agePrefMin ?? 18,
                    max: me?.agePrefMax ?? 99,
                    hint: l.ageRangeHint,
                    onChangeEnd: (a, b) => _saveAge(context, ref, a, b),
                  ),
                  const Divider(height: 24),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: ref.watch(preferNearbyProvider) && (me?.hasLocation ?? false) && !(me?.locationHidden ?? false),
                    onChanged: (v) => _togglePreferNearby(context, ref, v),
                    title: Text(l.preferNearby, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(l.preferNearbyDesc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    secondary: const Icon(Icons.near_me_rounded, color: AppColors.cyan),
                  ),
                ]),
              ),
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

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassCard(
      key: const Key('nearbyCard'),
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.location_on_rounded, color: AppColors.mint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.nearbyTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(l.nearbyDesc, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ]),
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
