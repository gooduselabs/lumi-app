import '../../auth/domain/user.dart';

enum DeliveryStatus { sending, sent, failed }

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
  });

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
        type: type, clientId: clientId, status: status ?? this.status,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        type: (j['type'] as String?) ?? 'TEXT',
        body: j['body'] as String,
        clientId: j['clientId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
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
