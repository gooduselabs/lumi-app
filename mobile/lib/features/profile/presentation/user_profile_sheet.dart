import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/domain/user.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../data/profile_repository.dart';

/// Public profile with report/block actions. Returns true if the user was blocked.
Future<bool?> showUserProfileSheet(BuildContext context, PublicUser user, {Widget? extraAction}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UserProfileSheet(user: user, extraAction: extraAction),
  );
}

class _UserProfileSheet extends ConsumerWidget {
  const _UserProfileSheet({required this.user, this.extraAction});
  final PublicUser user;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(profileRepositoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LumiAvatar(avatarId: user.avatarId, size: 96, ring: true, online: user.online),
          const SizedBox(height: 12),
          Text(user.nickname, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            [l.genderLabel(user.gender), if (user.age != null) l.ageYears(user.age!)].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(user.bio!, textAlign: TextAlign.center),
          ],
          if (user.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final i in user.interests) InterestChip(keyName: i),
            ]),
          ],
          const SizedBox(height: 20),
          ?extraAction,
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showReportSheet(context, (r, d) => repo.report(user.id, r, details: d, context: 'profile')),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l.report),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (!await confirmDialog(context, l.blockConfirm, confirm: l.block, danger: true)) return;
                  try {
                    await repo.block(user.id);
                    if (context.mounted) Navigator.pop(context, true);
                  } on ApiException catch (e) {
                    if (context.mounted) showSnack(context, l.errorText(e), error: true);
                  }
                },
                icon: const Icon(Icons.block_rounded),
                label: Text(l.block),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
