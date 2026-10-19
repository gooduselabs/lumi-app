import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/l10n_ext.dart';
import '../../../core/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../../core/widgets/lumi_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(meProvider);
    final locale = ref.watch(localeProvider).languageCode;

    Widget section(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: children)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        section([
          ListTile(leading: const Icon(Icons.alternate_email_rounded), title: Text(l.email), subtitle: Text(me?.email ?? '')),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(l.language),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'vi', label: Text('VI')), ButtonSegment(value: 'en', label: Text('EN'))],
              selected: {locale},
              onSelectionChanged: (s) {
                ref.read(localeProvider.notifier).set(s.first);
                ref.read(profileRepositoryProvider).update({'locale': s.first}).ignore();
              },
            ),
          ),
        ]),
        section([
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: Text(l.blockedUsers),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/blocked'),
          ),
          ListTile(
            leading: const Icon(Icons.shield_moon_outlined),
            title: Text(l.safetyCenter),
            subtitle: Text(l.safetyText, style: const TextStyle(fontSize: 12)),
          ),
        ]),
        section([
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l.about),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: Env.appName,
              applicationVersion: Env.appVersion,
              applicationIcon: const LumiLogo(size: 48, animate: false),
              applicationLegalese: l.appTagline,
            ),
          ),
          ListTile(leading: const Icon(Icons.dns_outlined), title: Text(l.server), subtitle: Text(Env.apiBaseUrl)),
          ListTile(leading: const Icon(Icons.tag_rounded), title: Text(l.version), subtitle: const Text(Env.appVersion)),
        ]),
        section([
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.amber),
            title: Text(l.logout),
            onTap: () async {
              if (await confirmDialog(context, l.logoutConfirm, confirm: l.logout)) {
                await ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            title: Text(l.deleteAccount, style: const TextStyle(color: AppColors.danger)),
            onTap: () async {
              if (!await confirmDialog(context, l.deleteAccountConfirm, confirm: l.deleteAccount, danger: true)) return;
              try {
                await ref.read(authControllerProvider.notifier).deleteAccount();
              } on ApiException catch (e) {
                if (context.mounted) showSnack(context, l.errorText(e), error: true);
              }
            },
          ),
        ]),
      ]),
    );
  }
}

final blockedUsersProvider = FutureProvider.autoDispose<List<PublicUser>>((ref) => ref.watch(profileRepositoryProvider).blocks());

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.blockedUsers)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(blockedUsersProvider)),
        data: (list) => list.isEmpty
            ? EmptyView(emoji: '🕊️', title: l.noBlocked)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  leading: LumiAvatar(avatarId: list[i].avatarId, size: 44),
                  title: Text(list[i].nickname),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      await ref.read(profileRepositoryProvider).unblock(list[i].id);
                      ref.invalidate(blockedUsersProvider);
                    },
                    child: Text(l.unblock),
                  ),
                ),
              ),
      ),
    );
  }
}
