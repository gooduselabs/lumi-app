import 'dart:typed_data';

import '../../../core/config/env.dart';
import '../../auth/domain/user.dart';

enum DeliveryStatus { sending, sent, failed }

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileName,
    required this.url,
    this.durationMs,
    this.width,
    this.height,
  });

  final String id;
  final String kind; // IMAGE | VOICE | FILE
  final String mimeType;
  final int sizeBytes;
  final String fileName;
  /// Signed, server-relative URL (no auth header needed).
  final String url;
  final int? durationMs;
  final int? width;
  final int? height;

  String get absoluteUrl => url.startsWith('http') ? url : '${Env.apiBaseUrl}$url';
  String get downloadUrl => '$absoluteUrl${absoluteUrl.contains('?') ? '&' : '?'}download=1';

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        id: j['id'] as String,
        kind: j['kind'] as String,
        mimeType: j['mimeType'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        fileName: j['fileName'] as String,
        url: j['url'] as String,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );
}

/// A media message being uploaded (kept for optimistic preview + retry).
class PendingMedia {
  const PendingMedia({required this.kind, required this.bytes, required this.fileName, this.mimeType, this.durationMs, this.width, this.height});
  final String kind;
  final Uint8List bytes;
  final String fileName;
  final String? mimeType;
  final int? durationMs;
  final int? width;
  final int? height;
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

String formatDuration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.type = 'TEXT',
    this.clientId,
    this.status = DeliveryStatus.sent,
    this.attachment,
    this.pending,
  });

  final ChatAttachment? attachment;
  final PendingMedia? pending;
  bool get isMedia => type == 'IMAGE' || type == 'VOICE' || type == 'FILE';

  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String body;
  final String? clientId;
  final DateTime createdAt;
  final DeliveryStatus status;

  bool get isSystem => type == 'SYSTEM';

  ChatMessage copyWith({DeliveryStatus? status}) => ChatMessage(
        id: id, conversationId: conversationId, senderId: senderId, body: body, createdAt: createdAt,
        type: type, clientId: clientId, status: status ?? this.status, attachment: attachment, pending: pending,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        type: (j['type'] as String?) ?? 'TEXT',
        body: j['body'] as String,
        clientId: j['clientId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attachment: j['attachment'] == null ? null : ChatAttachment.fromJson(Map<String, dynamic>.from(j['attachment'] as Map)),
      );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.peer,
    required this.updatedAt,
    this.lastMessage,
    this.unread = 0,
    this.peerLastReadAt,
  });

  final String id;
  final PublicUser peer;
  final ChatMessage? lastMessage;
  final int unread;
  final DateTime? peerLastReadAt;
  final DateTime updatedAt;

  Conversation copyWith({PublicUser? peer, ChatMessage? lastMessage, int? unread, DateTime? peerLastReadAt, DateTime? updatedAt}) =>
      Conversation(
        id: id,
        peer: peer ?? this.peer,
        lastMessage: lastMessage ?? this.lastMessage,
        unread: unread ?? this.unread,
        peerLastReadAt: peerLastReadAt ?? this.peerLastReadAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        peer: PublicUser.fromJson(Map<String, dynamic>.from(j['peer'] as Map)),
        lastMessage: j['lastMessage'] == null ? null : ChatMessage.fromJson(Map<String, dynamic>.from(j['lastMessage'] as Map)),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        peerLastReadAt: j['peerLastReadAt'] == null ? null : DateTime.parse(j['peerLastReadAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class Friend {
  const Friend(this.user, this.conversationId);
  final PublicUser user;
  final String conversationId;
}
