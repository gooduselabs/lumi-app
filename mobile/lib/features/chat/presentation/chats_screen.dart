import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/presentation/user_profile_sheet.dart';
import '../application/conversations_controller.dart';
import '../domain/chat_models.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [Text(l.chatsTitle, style: Theme.of(context).textTheme.headlineMedium)]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: [Tab(text: l.chatsTitle), Tab(text: l.friendsTitle)],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(child: TabBarView(children: [_ConversationList(), _FriendList()])),
        ]),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(conversationsProvider);
    final me = ref.watch(meProvider);
    final locale = ref.watch(localeProvider).languageCode;
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(conversationsProvider)),
      data: (list) => RefreshIndicator(
        onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
        child: list.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 420,
                  child: EmptyView(
                    emoji: '💬',
                    title: l.noChats,
                    subtitle: l.noChatsHint,
                    action: FilledButton(onPressed: () => context.go('/discover'), child: Text(l.goMatch)),
                  ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, i) => _ConversationTile(c: list[i], meId: me?.id, locale: locale),
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c, required this.meId, required this.locale});
  final Conversation c;
  final String? meId;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = c.lastMessage;
    final preview = last == null
        ? ''
        : last.isSystem
            ? l.systemMatched
            : '${last.senderId == meId ? '${l.you}: ' : ''}${switch (last.type) {
                'IMAGE' => '📷 ${l.photoMessage}',
                'VOICE' => '🎤 ${l.voiceMessage}',
                'FILE' => '📎 ${last.attachment?.fileName ?? ''}',
                _ => last.body,
              }}';
    final unread = c.unread > 0;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: () => context.push('/chat/${c.id}'),
      leading: LumiAvatar(avatarId: c.peer.avatarId, size: 52, online: c.peer.online),
      title: Text(c.peer.nickname, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unread ? AppColors.text : AppColors.textMuted, fontWeight: unread ? FontWeight.w600 : FontWeight.w400),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatRelative(c.updatedAt, locale), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
        const SizedBox(height: 6),
        AnimatedScale(
          scale: unread ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
            child: Text(c.unread > 99 ? '99+' : '${c.unread}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class _FriendList extends ConsumerWidget {
  const _FriendList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(friendsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(friendsProvider)),
      data: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(friendsProvider.future),
        child: list.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 420,
                  child: EmptyView(
                    emoji: '🫶',
                    title: l.noFriends,
                    subtitle: l.noChatsHint,
                    action: FilledButton(onPressed: () => context.go('/discover'), child: Text(l.goMatch)),
                  ),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final f = list[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: LumiAvatar(avatarId: f.user.avatarId, size: 48, online: f.user.online),
                    title: Text(f.user.nickname, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(f.user.online ? l.online : l.offline,
                        style: TextStyle(color: f.user.online ? AppColors.mint : AppColors.textFaint, fontSize: 12)),
                    onTap: () => showUserProfileSheet(
                      context,
                      f.user,
                      extraAction: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GradientButton(
                          label: l.sayHi,
                          icon: Icons.chat_rounded,
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/chat/${f.conversationId}');
                          },
                        ),
                      ),
                    ).then((blocked) {
                      if (blocked == true) {
                        ref.invalidate(friendsProvider);
                        ref.read(conversationsProvider.notifier).refresh();
                      }
                    }),
                    trailing: IconButton(
                      onPressed: () => context.push('/chat/${f.conversationId}'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.violet),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
