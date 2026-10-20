import 'dart:async';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/chat_repository.dart';
import '../data/chat_sync.dart';
import '../data/local_chat_store.dart';
import '../domain/chat_models.dart';
import 'conversations_controller.dart';

class ChatState {
  const ChatState({
    this.loading = true,
    this.peer,
    this.messages = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.peerTyping = false,
    this.peerLastReadAt,
    this.blocked = false,
    this.error,
  });

  final bool loading;
  final PublicUser? peer;

  /// Newest first (rendered in a reversed ListView).
  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingMore;
  final bool peerTyping;
  final DateTime? peerLastReadAt;
  final bool blocked;
  final Object? error;

  ChatState copyWith({
    bool? loading,
    PublicUser? peer,
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loadingMore,
    bool? peerTyping,
    DateTime? peerLastReadAt,
    bool? blocked,
    Object? error,
    bool clearError = false,
  }) =>
      ChatState(
        loading: loading ?? this.loading,
        peer: peer ?? this.peer,
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        peerTyping: peerTyping ?? this.peerTyping,
        peerLastReadAt: peerLastReadAt ?? this.peerLastReadAt,
        blocked: blocked ?? this.blocked,
        error: clearError ? null : (error ?? this.error),
      );
}

final chatControllerProvider = NotifierProvider.autoDispose.family<ChatController, ChatState, String>(ChatController.new);

/// One conversation. Reads history from the on-device store; the server only relays.
class ChatController extends Notifier<ChatState> {
  ChatController(this.conversationId);
  final String conversationId;

  static const pageSize = 50;
  static const maxUploadBytes = 20 * 1024 * 1024;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String? get _me => ref.read(meProvider)?.id;
  ChatSync? _sync;
  LocalChatStore? get _store => _sync?.store;
  Timer? _typingOff;
  bool _iAmTyping = false;
  Timer? _stopTypingTimer;
  StreamSubscription? _changesSub;

  @override
  ChatState build() {
    final s = _repo.socket;
    final subs = <StreamSubscription>[
      s.on('chat:message').listen(_onMessageEvent),
      s.on('chat:typing').listen(_onTyping),
      s.on('presence:update').listen(_onPresence),
    ];
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
      _changesSub?.cancel();
      _typingOff?.cancel();
      _stopTypingTimer?.cancel();
    });
    Future.microtask(load);
    return const ChatState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      _sync = await ref.read(chatSyncProvider.future);
      final store = _store;
      if (store == null || !ref.mounted) return;
      _changesSub ??= store.changes.where((c) => c == conversationId).listen((_) => _reload());
      // Peer/blocked info from the server when reachable; cached locally for offline use.
      try {
        final info = await _repo.conversation(conversationId);
        await store.upsertConversation(conversationId, info.peer, peerLastReadAt: info.peerLastReadAt);
        if (!ref.mounted) return;
        state = state.copyWith(peer: info.peer, blocked: info.blocked);
      } catch (e) {
        final cached = (await store.conversations(_me ?? '')).where((c) => c.id == conversationId).firstOrNull;
        if (cached == null) rethrow;
        state = state.copyWith(peer: cached.peer);
      }
      final items = await store.messages(conversationId, limit: pageSize);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        messages: items,
        hasMore: items.length == pageSize,
        peerLastReadAt: await store.peerLastReadAt(conversationId),
      );
      _markRead();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> _reload() async {
    final store = _store;
    if (store == null || !ref.mounted) return;
    final n = state.messages.length < pageSize ? pageSize : state.messages.length + 1;
    final items = await store.messages(conversationId, limit: n);
    final plr = await store.peerLastReadAt(conversationId);
    if (!ref.mounted) return;
    state = state.copyWith(messages: items, peerLastReadAt: plr);
  }

  Future<void> loadMore() async {
    final store = _store;
    if (store == null || !state.hasMore || state.loadingMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    final older = await store.messages(conversationId, before: state.messages.last.createdAt, limit: pageSize);
    if (!ref.mounted) return;
    state = state.copyWith(messages: [...state.messages, ...older], hasMore: older.length == pageSize, loadingMore: false);
  }

  Future<void> send(String text, {ChatMessage? retry}) async {
    final body = text.trim();
    final me = _me;
    final store = _store;
    if (body.isEmpty || me == null || store == null) return;
    final clientId = retry?.clientId ?? 'c${DateTime.now().microsecondsSinceEpoch}';
    await store.upsert(ChatMessage(
      id: retry?.id ?? clientId,
      conversationId: conversationId,
      senderId: me,
      body: body,
      clientId: clientId,
      createdAt: retry?.createdAt ?? DateTime.now(),
      status: DeliveryStatus.sending,
    ));
    _setTyping(false);
    try {
      final saved = await _repo.send(conversationId, body, clientId);
      await store.upsert(saved.copyWith(status: DeliveryStatus.sent));
    } on ApiException catch (e) {
      await store.setStatus(conversationId, clientId, DeliveryStatus.failed);
      if (ref.mounted) state = state.copyWith(error: e, blocked: e.code == 'BLOCKED' ? true : null);
    }
  }

  /// Saves my copy of the file locally, shows it immediately, then uploads.
  Future<void> sendMedia(PendingMedia media, {ChatMessage? retry}) async {
    final me = _me;
    final sync = _sync;
    if (me == null || sync == null) return;
    if (media.bytes.length > maxUploadBytes) {
      state = state.copyWith(error: ApiException('FILE_TOO_LARGE', 'File too large'));
      return;
    }
    final clientId = retry?.clientId ?? 'm${DateTime.now().microsecondsSinceEpoch}';
    final path = retry?.attachment?.localPath ?? await sync.saveOutgoing(conversationId, clientId, media);
    final local = ChatAttachment(
      id: clientId,
      kind: media.kind,
      mimeType: media.mimeType ?? 'application/octet-stream',
      sizeBytes: media.bytes.length,
      fileName: media.fileName,
      url: '',
      durationMs: media.durationMs,
      width: media.width,
      height: media.height,
      localPath: path,
    );
    await sync.store.upsert(ChatMessage(
      id: retry?.id ?? clientId,
      conversationId: conversationId,
      senderId: me,
      body: '',
      type: media.kind,
      clientId: clientId,
      createdAt: retry?.createdAt ?? DateTime.now(),
      status: DeliveryStatus.sending,
      attachment: local,
    ));
    try {
      final saved = await _repo.sendMedia(conversationId, media, clientId);
      await sync.store.upsert(saved.copyWith(status: DeliveryStatus.sent, attachment: saved.attachment?.withLocalPath(path)));
    } on ApiException catch (e) {
      await sync.store.setStatus(conversationId, clientId, DeliveryStatus.failed);
      if (ref.mounted) state = state.copyWith(error: e, blocked: e.code == 'BLOCKED' ? true : null);
    }
  }

  Future<void> retry(ChatMessage m) async {
    final a = m.attachment;
    if (m.isMedia && a?.localPath != null) {
      final bytes = await File(a!.localPath!).readAsBytes();
      await sendMedia(
        PendingMedia(kind: m.type, bytes: bytes, fileName: a.fileName, mimeType: a.mimeType, durationMs: a.durationMs, width: a.width, height: a.height),
        retry: m,
      );
    } else {
      await send(m.body, retry: m);
    }
  }

  void onInputChanged(String text) {
    if (text.isNotEmpty) {
      _setTyping(true);
      _stopTypingTimer?.cancel();
      _stopTypingTimer = Timer(const Duration(seconds: 3), () => _setTyping(false));
    } else {
      _setTyping(false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _setTyping(bool v) {
    if (_iAmTyping == v) return;
    _iAmTyping = v;
    _repo.typing(conversationId, v);
  }

  void _markRead() {
    unawaited(_store?.markRead(conversationId, DateTime.now()));
    ref.read(conversationsProvider.notifier).markLocallyRead(conversationId);
    unawaited(_repo.markRead(conversationId).catchError((_) {}));
  }

  /// The sync engine stores the message; here we only react (typing indicator, read receipt).
  void _onMessageEvent(Map<String, dynamic> d) {
    if (d['conversationId'] != conversationId || d['senderId'] == _me) return;
    _typingOff?.cancel();
    state = state.copyWith(peerTyping: false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (ref.mounted) _markRead();
    });
  }

  void _onTyping(Map<String, dynamic> d) {
    if (d['conversationId'] != conversationId) return;
    final typing = d['isTyping'] == true;
    state = state.copyWith(peerTyping: typing);
    _typingOff?.cancel();
    if (typing) _typingOff = Timer(const Duration(seconds: 5), () => state = state.copyWith(peerTyping: false));
  }

  void _onPresence(Map<String, dynamic> d) {
    final p = state.peer;
    if (p == null || d['userId'] != p.id) return;
    state = state.copyWith(peer: p.copyWith(online: d['online'] == true));
  }
}
