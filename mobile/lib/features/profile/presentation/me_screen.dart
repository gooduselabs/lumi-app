import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/conversations_controller.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    final friends = ref.watch(friendsProvider).value?.length;
    if (me == null) return const LoadingView();
    return GlowBackground(
      intensity: 0.7,
      child: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
          Row(children: [
            Text(l.me, style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            IconButton(
              style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ]),
          const SizedBox(height: 20),
          Center(child: LumiAvatar(avatarId: me.avatarId, size: 120, ring: true)),
          const SizedBox(height: 14),
          Center(child: Text(me.nickname ?? '', style: Theme.of(context).textTheme.headlineSmall)),
          const SizedBox(height: 4),
          Center(
            child: Text(
              [l.genderLabel(me.gender), if (me.age != null) l.ageYears(me.age!)].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (me.bio != null && me.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(child: Text(me.bio!, textAlign: TextAlign.center)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _Stat(value: '${friends ?? '–'}', label: l.friendsTitle)),
            const SizedBox(width: 12),
            Expanded(child: _Stat(value: '${me.interests.length}', label: l.interests)),
          ]),
          const SizedBox(height: 20),
          if (me.interests.isNotEmpty)
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.interests, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final i in me.interests) InterestChip(keyName: i)]),
              ]),
            ),
          const SizedBox(height: 20),
          GradientButton(label: l.editProfile, icon: Icons.edit_rounded, onPressed: () => context.push('/me/edit')),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          ShaderMask(
            shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
            child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
        ]),
      );
}
