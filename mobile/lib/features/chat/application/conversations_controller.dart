import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/chat_repository.dart';
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
      s.on('chat:message').listen(_onMessage),
      s.on('chat:read').listen(_onRead),
      s.on('presence:update').listen(_onPresence),
      s.on('friends:changed').listen((_) => refresh()),
      s.on('match:mutual').listen((_) => refresh()),
    ];
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
    });
    return repo.conversations();
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(ref.read(chatRepositoryProvider).conversations);
    state = next;
  }

  void markLocallyRead(String id) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final c in list) c.id == id ? c.copyWith(unread: 0) : c]);
  }

  void _onMessage(Map<String, dynamic> d) {
    final list = state.value;
    if (list == null) return;
    final m = ChatMessage.fromJson(d);
    final idx = list.indexWhere((c) => c.id == m.conversationId);
    if (idx < 0) {
      refresh();
      return;
    }
    final me = ref.read(meProvider)?.id;
    final active = ref.read(activeConversationProvider) == m.conversationId;
    final c = list[idx];
    final updated = c.copyWith(
      lastMessage: m,
      updatedAt: m.createdAt,
      unread: m.senderId == me || active ? c.unread : c.unread + 1,
    );
    state = AsyncData([updated, ...list.where((x) => x.id != c.id)]);
  }

  void _onRead(Map<String, dynamic> d) {
    final list = state.value;
    if (list == null) return;
    final id = d['conversationId'] as String;
    final at = DateTime.parse(d['readAt'] as String);
    state = AsyncData([for (final c in list) c.id == id ? c.copyWith(peerLastReadAt: at) : c]);
  }

  void _onPresence(Map<String, dynamic> d) {
    final list = state.value;
    if (list == null) return;
    final uid = d['userId'] as String;
    final online = d['online'] == true;
    state = AsyncData([for (final c in list) c.peer.id == uid ? c.copyWith(peer: c.peer.copyWith(online: online)) : c]);
  }
}
