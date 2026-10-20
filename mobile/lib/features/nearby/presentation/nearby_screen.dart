import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../../profile/presentation/user_profile_sheet.dart';
import '../application/nearby_controller.dart';
import 'filter_widgets.dart';

/// "Người gần đây": users around me, approximate distance only.
class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});
  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  bool _locating = false;

  Future<void> _share() async {
    setState(() => _locating = true);
    try {
      await ref.read(locationActionsProvider).share();
      ref.invalidate(nearbyUsersProvider);
    } catch (e) {
      if (mounted) showLocationError(context, e, ref.read(locationServiceProvider));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    final f = ref.watch(nearbyFilterProvider);
    final users = ref.watch(nearbyUsersProvider);
    final ready = me != null && me.hasLocation && !me.locationHidden;
    void setF(NearbyFilter n) => ref.read(nearbyFilterProvider.notifier).set(n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.nearbyTitle),
        actions: [
          if (ready)
            IconButton(
              tooltip: l.updateLocation,
              onPressed: _locating ? null : _share,
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
        ],
      ),
      body: GlowBackground(
        intensity: 0.5,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(nearbyUsersProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.radius, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final r in kRadiusOptions)
                    ChoiceChip(label: Text(l.radiusKm(r)), selected: f.radiusKm == r, onSelected: (_) => setF(f.copyWith(radiusKm: r))),
                ]),
                const SizedBox(height: 12),
                AgeRangeField(min: f.minAge, max: f.maxAge, onChangeEnd: (a, b) => setF(f.copyWith(minAge: a, maxAge: b))),
                const SizedBox(height: 4),
                Text(l.genderFilter, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GenderChips(value: f.gender, onChanged: (g) => setF(f.copyWith(gender: g))),
              ]),
            ),
            const SizedBox(height: 14),
            if (!ready)
              _LocationPrompt(hidden: me?.locationHidden == true, busy: _locating, onEnable: _share)
            else
              users.when(
                loading: () => const Padding(padding: EdgeInsets.all(40), child: LoadingView()),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(nearbyUsersProvider)),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: EmptyView(emoji: '📍', title: l.nearbyTitle, subtitle: l.nearbyEmpty),
                      )
                    : Column(children: [for (final u in list) _NearbyTile(user: u)]),
              ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textFaint),
              const SizedBox(width: 6),
              Expanded(child: Text(l.locationWhy, style: const TextStyle(color: AppColors.textFaint, fontSize: 12))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.hidden, required this.busy, required this.onEnable});
  final bool hidden;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassCard(
      child: Column(children: [
        const Icon(Icons.location_on_rounded, size: 44, color: AppColors.cyan),
        const SizedBox(height: 10),
        Text(hidden ? l.locationHiddenInfo : l.locationWhy, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 14),
        GradientButton(label: l.locationEnable, loading: busy, onPressed: onEnable),
      ]),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({required this.user});
  final PublicUser user;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sub = [l.genderLabel(user.gender), if (user.age != null) l.ageYears(user.age!)].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => showUserProfileSheet(context, user),
        child: Row(children: [
          LumiAvatar(avatarId: user.avatarId, size: 52, online: user.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              if (user.interests.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user.interests.take(3).map((i) => '${kInterestEmoji[i] ?? ''} ${l.interest(i)}').join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                ),
              ],
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.near_me_rounded, size: 14, color: AppColors.cyan),
              const SizedBox(width: 4),
              Text(l.distanceApprox(user.distanceKm ?? 1), style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}
