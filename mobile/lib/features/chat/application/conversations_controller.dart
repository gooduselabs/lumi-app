import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/chat_repository.dart';
import '../data/chat_sync.dart';
import '../domain/chat_models.dart';

/// Conversation currently on screen (so it doesn't count as unread).
final activeConversationProvider = NotifierProvider<ActiveConversation, String?>(ActiveConversation.new);

class ActiveConversation extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final conversationsProvider = AsyncNotifierProvider<ConversationsController, List<Conversation>>(ConversationsController.new);

final totalUnreadProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider).value ?? const [];
  return list.fold(0, (a, c) => a + c.unread);
});

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final meId = ref.watch(meProvider.select((m) => m?.id));
  if (meId == null) return const [];
  final repo = ref.watch(chatRepositoryProvider);
  final sub = repo.socket.events
      .where((e) => e.name == 'friends:changed' || e.name == 'presence:update')
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.friends();
});

class ConversationsController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final meId = ref.watch(meProvider.select((m) => m?.id)); // reset on account switch
    if (meId == null) return const [];
    final repo = ref.read(chatRepositoryProvider);
    final s = repo.socket;
    final subs = <StreamSubscription>[
      s.on('presence:update').listen(_onPresence),
      s.on('friends:changed').listen((_) => refresh()),
      s.on('match:mutual').listen((_) => refresh()),
    ];
    final sync = await ref.watch(chatSyncProvider.future);
    if (sync != null) subs.add(sync.store.changes.listen((_) => _recompute()));
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
    });
    return _load(sync, meId);
  }

  /// Friend list (peers, online) from the server when reachable, merged with
  /// on-device last message / unread / receipts. Offline: local cache only.
  Future<List<Conversation>> _load(ChatSync? sync, String meId) async {
    final store = sync?.store;
    if (store == null) return ref.read(chatRepositoryProvider).conversations();
    List<Conversation>? remote;
    try {
      remote = await ref.read(chatRepositoryProvider).conversations();
      for (final c in remote) {
        await store.upsertConversation(c.id, c.peer, peerLastReadAt: c.peerLastReadAt, updatedAt: c.updatedAt);
      }
    } catch (_) {}
    final local = {for (final c in await store.conversations(meId)) c.id: c};
    if (remote == null) return local.values.toList();
    final merged = [
      for (final c in remote)
        Conversation(
          id: c.id,
          peer: c.peer,
          lastMessage: local[c.id]?.lastMessage,
          unread: (local[c.id]?.unread ?? 0),
          peerLastReadAt: local[c.id]?.peerLastReadAt ?? c.peerLastReadAt,
          updatedAt: local[c.id]?.lastMessage?.createdAt ?? c.updatedAt,
        ),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged;
  }

  Timer? _debounce;
  void _recompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final sync = ref.read(chatSyncProvider).value;
      final meId = ref.read(meProvider)?.id;
      final list = state.value;
      if (sync == null || meId == null || list == null) return;
      final local = {for (final c in await sync.store.conversations(meId)) c.id: c};
      final active = ref.read(activeConversationProvider);
      final next = [
        for (final c in list)
          c.copyWith(
            lastMessage: local[c.id]?.lastMessage,
            unread: c.id == active ? 0 : local[c.id]?.unread ?? c.unread,
            peerLastReadAt: local[c.id]?.peerLastReadAt,
            updatedAt: local[c.id]?.lastMessage?.createdAt,
          ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (local.keys.any((id) => !list.any((c) => c.id == id))) return refresh();
      state = AsyncData(next);
    });
  }

  Future<void> refresh() async {
    final meId = ref.read(meProvider)?.id;
    if (meId == null) return;
    final sync = ref.read(chatSyncProvider).value;
    state = await AsyncValue.guard(() => _load(sync, meId));
  }

  void markLocallyRead(String id) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final c in list) c.id == id ? c.copyWith(unread: 0) : c]);
  }

  void _onPresence(Map<String, dynamic> d) {
    final list = state.value;
    if (list == null) return;
    final uid = d['userId'] as String;
    final online = d['online'] == true;
    state = AsyncData([for (final c in list) c.peer.id == uid ? c.copyWith(peer: c.peer.copyWith(online: online)) : c]);
  }
}
