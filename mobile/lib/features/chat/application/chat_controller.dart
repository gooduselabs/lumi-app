import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../data/chat_repository.dart';
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

class ChatController extends Notifier<ChatState> {
  ChatController(this.conversationId);
  final String conversationId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String? get _me => ref.read(meProvider)?.id;
  Timer? _typingOff;
  bool _iAmTyping = false;
  Timer? _stopTypingTimer;

  @override
  ChatState build() {
    final s = _repo.socket;
    final subs = <StreamSubscription>[
      s.on('chat:message').listen(_onMessage),
      s.on('chat:typing').listen(_onTyping),
      s.on('chat:read').listen(_onRead),
      s.on('presence:update').listen(_onPresence),
    ];
    ref.onDispose(() {
      for (final x in subs) {
        x.cancel();
      }
      _typingOff?.cancel();
      _stopTypingTimer?.cancel();
    });
    Future.microtask(load);
    return const ChatState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final info = await _repo.conversation(conversationId);
      final page = await _repo.history(conversationId);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        peer: info.peer,
        peerLastReadAt: info.peerLastReadAt,
        blocked: info.blocked,
        messages: page.items,
        hasMore: page.hasMore,
      );
      _markRead();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.history(conversationId, before: state.messages.last.createdAt);
      if (!ref.mounted) return;
      state = state.copyWith(messages: [...state.messages, ...page.items], hasMore: page.hasMore, loadingMore: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> send(String text, {ChatMessage? retry}) async {
    final body = text.trim();
    final me = _me;
    if (body.isEmpty || me == null) return;
    final clientId = retry?.clientId ?? 'c${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: retry?.id ?? clientId,
      conversationId: conversationId,
      senderId: me,
      body: body,
      clientId: clientId,
      createdAt: retry?.createdAt ?? DateTime.now(),
      status: DeliveryStatus.sending,
    );
    state = state.copyWith(messages: [pending, ...state.messages.where((m) => m.id != pending.id)]);
    _setTyping(false);
    try {
      final saved = await _repo.send(conversationId, body, clientId);
      if (!ref.mounted) return;
      _replace(clientId, saved);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: [for (final m in state.messages) m.clientId == clientId && m.status == DeliveryStatus.sending ? m.copyWith(status: DeliveryStatus.failed) : m],
        error: e,
        blocked: e.code == 'BLOCKED' ? true : null,
      );
    }
  }

  static const maxUploadBytes = 20 * 1024 * 1024;

  /// Optimistically shows the media bubble, uploads, then swaps in the server message.
  Future<void> sendMedia(PendingMedia media, {ChatMessage? retry}) async {
    final me = _me;
    if (me == null) return;
    if (media.bytes.length > maxUploadBytes) {
      state = state.copyWith(error: ApiException('FILE_TOO_LARGE', 'File too large'));
      return;
    }
    final clientId = retry?.clientId ?? 'm${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: retry?.id ?? clientId,
      conversationId: conversationId,
      senderId: me,
      body: '',
      type: media.kind,
      clientId: clientId,
      createdAt: retry?.createdAt ?? DateTime.now(),
      status: DeliveryStatus.sending,
      pending: media,
    );
    state = state.copyWith(messages: [pending, ...state.messages.where((m) => m.id != pending.id)]);
    try {
      final saved = await _repo.sendMedia(conversationId, media, clientId);
      if (!ref.mounted) return;
      _replace(clientId, saved);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: [for (final m in state.messages) m.clientId == clientId && m.status == DeliveryStatus.sending ? m.copyWith(status: DeliveryStatus.failed) : m],
        error: e,
        blocked: e.code == 'BLOCKED' ? true : null,
      );
    }
  }

  void retry(ChatMessage m) => m.pending != null ? sendMedia(m.pending!, retry: m) : send(m.body, retry: m);

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

  void _replace(String clientId, ChatMessage saved) {
    final exists = state.messages.any((m) => m.id == saved.id);
    state = state.copyWith(
      messages: exists
          ? state.messages.where((m) => m.clientId != clientId || m.id == saved.id).toList()
          : [for (final m in state.messages) m.clientId == clientId ? saved : m],
    );
  }

  void _markRead() {
    ref.read(conversationsProvider.notifier).markLocallyRead(conversationId);
    unawaited(_repo.markRead(conversationId).catchError((_) {}));
  }

  void _onMessage(Map<String, dynamic> d) {
    final m = ChatMessage.fromJson(d);
    if (m.conversationId != conversationId) return;
    if (m.senderId == _me) {
      // Echo of my own message (maybe from another device): dedupe by clientId/id.
      if (m.clientId != null && state.messages.any((x) => x.clientId == m.clientId)) {
        _replace(m.clientId!, m);
        return;
      }
      if (state.messages.any((x) => x.id == m.id)) return;
    }
    _typingOff?.cancel();
    state = state.copyWith(messages: [m, ...state.messages], peerTyping: m.senderId == _me ? null : false);
    if (m.senderId != _me) _markRead();
  }

  void _onTyping(Map<String, dynamic> d) {
    if (d['conversationId'] != conversationId) return;
    final typing = d['isTyping'] == true;
    state = state.copyWith(peerTyping: typing);
    _typingOff?.cancel();
    if (typing) _typingOff = Timer(const Duration(seconds: 5), () => state = state.copyWith(peerTyping: false));
  }

  void _onRead(Map<String, dynamic> d) {
    if (d['conversationId'] != conversationId) return;
    state = state.copyWith(peerLastReadAt: DateTime.parse(d['readAt'] as String));
  }

  void _onPresence(Map<String, dynamic> d) {
    final p = state.peer;
    if (p == null || d['userId'] != p.id) return;
    state = state.copyWith(peer: p.copyWith(online: d['online'] == true));
  }
}
