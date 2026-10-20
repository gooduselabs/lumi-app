import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../auth/domain/user.dart';
import '../domain/chat_models.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(apiClientProvider), ref.watch(socketServiceProvider)));

class ChatRepository {
  ChatRepository(this._api, this._socket);
  final ApiClient _api;
  final SocketService _socket;

  SocketService get socket => _socket;

  Future<List<Conversation>> conversations() async =>
      (await _api.get<List>('/conversations')).map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<List<Friend>> friends() async => (await _api.get<List>('/friends')).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return Friend(PublicUser.fromJson(m), m['conversationId'] as String);
      }).toList();

  Future<({PublicUser peer, DateTime? peerLastReadAt, bool blocked})> conversation(String id) async {
    final j = await _api.get<Map>('/conversations/$id');
    return (
      peer: PublicUser.fromJson(Map<String, dynamic>.from(j['peer'] as Map)),
      peerLastReadAt: j['peerLastReadAt'] == null ? null : DateTime.parse(j['peerLastReadAt'] as String),
      blocked: j['blocked'] == true,
    );
  }

  /// Socket first (realtime ack); falls back to REST when the socket is down.
  Future<ChatMessage> send(String conversationId, String body, String clientId) async {
    final payload = {'conversationId': conversationId, 'body': body, 'clientId': clientId};
    try {
      final d = await _socket.request<Map>('chat:send', payload);
      return ChatMessage.fromJson(Map<String, dynamic>.from(d));
    } catch (e) {
      if (_socket.status.value == SocketStatus.connected) rethrow;
      final d = await _api.post<Map>('/conversations/$conversationId/messages', data: {'body': body, 'clientId': clientId});
      return ChatMessage.fromJson(Map<String, dynamic>.from(d));
    }
  }

  /// Multipart upload of an image / voice note / file; the server posts the message.
  Future<ChatMessage> sendMedia(String conversationId, PendingMedia m, String clientId, {String? caption, void Function(double)? onProgress}) async {
    final form = FormData.fromMap({
      'kind': m.kind,
      'clientId': clientId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (m.durationMs != null) 'durationMs': m.durationMs.toString(),
      if (m.width != null) 'width': m.width.toString(),
      if (m.height != null) 'height': m.height.toString(),
      'file': MultipartFile.fromBytes(m.bytes, filename: m.fileName, contentType: m.mimeType != null ? DioMediaType.parse(m.mimeType!) : null),
    });
    final d = await _api.upload<Map>('/conversations/$conversationId/media', form, onProgress: onProgress);
    return ChatMessage.fromJson(Map<String, dynamic>.from(d));
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _socket.request('chat:read', {'conversationId': conversationId});
    } catch (_) {
      await _api.post('/conversations/$conversationId/read');
    }
  }

  void typing(String conversationId, bool isTyping) =>
      _socket.send('chat:typing', {'conversationId': conversationId, 'isTyping': isTyping});

  Future<void> unfriend(String userId) => _api.delete('/friends/$userId');
}
