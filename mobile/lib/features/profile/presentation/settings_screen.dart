import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/config/server_config.dart';
import '../../../core/l10n_ext.dart';
import '../../../core/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../../core/widgets/lumi_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../../chat/application/conversations_controller.dart';
import '../../chat/data/local_db.dart';
import '../../nearby/application/nearby_controller.dart';
import '../data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    try {
      final store = await ref.read(localChatStoreProvider.future);
      if (store == null) return;
      final bytes = Uint8List.fromList(utf8.encode(await store.exportJson()));
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final uri = await FilePicker.saveFile(fileName: 'lumi-backup-$stamp.json', bytes: bytes, mimeType: 'application/json');
      if (uri != null && context.mounted) showSnack(context, l.backupDone);
    } catch (e) {
      if (context.mounted) showSnack(context, l.errorText(e), error: true);
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (files.isEmpty) return;
      final store = await ref.read(localChatStoreProvider.future);
      if (store == null) return;
      final n = await store.importJson(utf8.decode(await files.first.readAsBytes()));
      ref.invalidate(conversationsProvider);
      if (context.mounted) showSnack(context, l.restoreDone(n));
    } catch (e) {
      if (context.mounted) showSnack(context, l.errorText(e), error: true);
    }
  }

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
            leading: const Icon(Icons.phone_android_rounded),
            title: Text(l.localStorageNote, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: Text(l.exportBackup),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: Text(l.importBackup),
            onTap: () => _importBackup(context, ref),
          ),
        ]),
        section([
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.location_off_outlined),
            title: Text(l.hideLocation),
            subtitle: Text(l.hideLocationDesc, style: const TextStyle(fontSize: 12)),
            value: me?.locationHidden ?? false,
            onChanged: (v) => ref.read(locationActionsProvider).setHidden(v).catchError((Object e) {
              if (context.mounted) showSnack(context, l.errorText(e), error: true);
              return me!;
            }),
          ),
          if (me?.hasLocation ?? false)
            ListTile(
              leading: const Icon(Icons.wrong_location_outlined),
              title: Text(l.removeLocation),
              onTap: () => ref.read(locationActionsProvider).clear().ignore(),
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
          ListTile(leading: const Icon(Icons.dns_outlined), title: Text(l.server), subtitle: Text(ServerConfig.current)),
          ListTile(leading: const Icon(Icons.tag_rounded), title: Text(l.version), subtitle: const Text(Env.appVersion)),
        ]),
        section([
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.amber),
            title: Text(l.logout),
            onTap: () async {
              final choice = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.logoutKeepTitle),
                  content: Text(l.logoutKeepBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'wipe'),
                      child: Text(l.wipeData, style: const TextStyle(color: AppColors.danger)),
                    ),
                    FilledButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(l.keepData)),
                  ],
                ),
              );
              if (choice == null) return;
              await ref.read(authControllerProvider.notifier).logout(wipeLocal: choice == 'wipe');
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
