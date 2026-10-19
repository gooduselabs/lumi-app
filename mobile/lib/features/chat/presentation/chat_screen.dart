import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../match/presentation/match_screen.dart' show TypingDots;
import '../../moderation/presentation/report_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/user_profile_sheet.dart';
import '../application/chat_controller.dart';
import '../application/conversations_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ActiveConversation _active;

  @override
  void initState() {
    super.initState();
    _active = ref.read(activeConversationProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _active.set(widget.conversationId));
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    Future.microtask(() => _active.set(null));
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text;
    if (t.trim().isEmpty) return;
    ref.read(chatControllerProvider(widget.conversationId).notifier).send(t);
    _input.clear();
  }

  Future<void> _menu(String v) async {
    final l = context.l10n;
    final state = ref.read(chatControllerProvider(widget.conversationId));
    final peer = state.peer;
    if (peer == null) return;
    final profile = ref.read(profileRepositoryProvider);
    switch (v) {
      case 'profile':
        final blocked = await showUserProfileSheet(context, peer);
        if (blocked == true && mounted) _afterBlock();
      case 'report':
        await showReportSheet(context, (r, d) => profile.report(peer.id, r, details: d, context: 'chat:${widget.conversationId}'));
      case 'block':
        if (await confirmDialog(context, l.blockConfirm, confirm: l.block, danger: true)) {
          await profile.block(peer.id);
          if (mounted) _afterBlock();
        }
      case 'unfriend':
        if (await confirmDialog(context, l.unfriendConfirm, confirm: l.unfriend, danger: true)) {
          await ref.read(chatRepositoryProvider).unfriend(peer.id);
          if (mounted) _afterBlock();
        }
    }
  }

  void _afterBlock() {
    ref.read(conversationsProvider.notifier).refresh();
    ref.invalidate(friendsProvider);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    final meId = ref.watch(meProvider)?.id;
    ref.listen(chatControllerProvider(widget.conversationId).select((s) => s.error), (_, e) {
      if (e != null && !state.loading) {
        showSnack(context, l.errorText(e), error: true);
        ref.read(chatControllerProvider(widget.conversationId).notifier).clearError();
      }
    });

    final peer = state.peer;
    // Last of my messages the peer has seen -> show "Seen" under it.
    final lastMine = state.messages.where((m) => m.senderId == meId && !m.isSystem && m.status == DeliveryStatus.sent).firstOrNull;
    final seenId = lastMine != null && state.peerLastReadAt != null && !state.peerLastReadAt!.isBefore(lastMine.createdAt) ? lastMine.id : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: peer == null
            ? const SizedBox.shrink()
            : InkWell(
                onTap: () => _menu('profile'),
                child: Row(children: [
                  LumiAvatar(avatarId: peer.avatarId, size: 40, online: peer.online),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(peer.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          state.peerTyping ? l.partnerTyping : (peer.online ? l.online : l.offline),
                          key: ValueKey('${state.peerTyping}${peer.online}'),
                          style: TextStyle(fontSize: 12, color: state.peerTyping || peer.online ? AppColors.mint : AppColors.textFaint),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'profile', child: Text(l.viewProfile)),
              PopupMenuItem(value: 'report', child: Text(l.report)),
              PopupMenuItem(value: 'unfriend', child: Text(l.unfriend)),
              PopupMenuItem(value: 'block', child: Text(l.block, style: const TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
      body: state.loading
          ? const LoadingView()
          : state.error != null && state.peer == null
              ? ErrorView(error: state.error!, onRetry: ref.read(chatControllerProvider(widget.conversationId).notifier).load)
              : Column(children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: state.messages.length + (state.loadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == state.messages.length) {
                          return const Padding(padding: EdgeInsets.all(12), child: LoadingView());
                        }
                        final m = state.messages[i];
                        final older = i + 1 < state.messages.length ? state.messages[i + 1] : null;
                        final showDay = older == null || !_sameDay(older.createdAt, m.createdAt);
                        return Column(children: [
                          if (showDay) _DayDivider(m.createdAt),
                          if (m.isSystem)
                            _SystemNote(text: l.systemMatched)
                          else
                            _MessageBubble(
                              m: m,
                              mine: m.senderId == meId,
                              seen: m.id == seenId,
                              onRetry: () => ref.read(chatControllerProvider(widget.conversationId).notifier).send(m.body, retry: m),
                            ),
                        ]);
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: state.peerTyping
                        ? Padding(
                            padding: const EdgeInsets.only(left: 20, bottom: 6),
                            child: Align(alignment: Alignment.centerLeft, child: TypingDots(label: l.partnerTyping)),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (state.blocked)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l.chatBlocked, style: const TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 2000,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: ref.read(chatControllerProvider(widget.conversationId).notifier).onInputChanged,
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
                    ),
                ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider(this.t);
  final DateTime t;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(DateFormat('dd/MM/yyyy').format(t.toLocal()), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
      );
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.m, required this.mine, required this.seen, required this.onRetry});
  final ChatMessage m;
  final bool mine;
  final bool seen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = m.status == DeliveryStatus.failed;
    final status = switch (m.status) {
      DeliveryStatus.sending => l.sending,
      DeliveryStatus.failed => l.failedTapRetry,
      DeliveryStatus.sent => seen ? l.seen : null,
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: failed ? onRetry : null,
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              gradient: mine && !failed ? AppColors.primaryGradient : null,
              color: failed ? AppColors.danger.withValues(alpha: 0.25) : (mine ? null : AppColors.surfaceHigh),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mine ? 20 : 6),
                bottomRight: Radius.circular(mine ? 6 : 20),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m.body, style: const TextStyle(fontSize: 15, height: 1.3)),
              const SizedBox(height: 2),
              Text(formatClock(m.createdAt), style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
            ]),
          ),
          if (mine && status != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (seen) const Icon(Icons.done_all_rounded, size: 14, color: AppColors.cyan),
                const SizedBox(width: 3),
                Text(status, style: TextStyle(fontSize: 11, color: failed ? AppColors.danger : AppColors.textFaint)),
              ]),
            ),
        ]),
      ),
    );
  }
}
