import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart' show firstIntValue;

import '../../auth/domain/user.dart';
import '../domain/chat_models.dart';

/// On-device chat history (the server only relays). Works on any sqflite [Database]:
/// SQLCipher-encrypted in the app, plain in-memory sqlite in tests.
class LocalChatStore {
  LocalChatStore(this.db);
  final Database db;

  final _changes = StreamController<String>.broadcast();

  /// Emits a conversation id whenever its messages/receipts change.
  Stream<String> get changes => _changes.stream;

  static const schemaVersion = 1;

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        peer_json TEXT NOT NULL,
        last_read_at INTEGER,
        peer_last_read_at INTEGER,
        updated_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        type TEXT NOT NULL,
        body TEXT NOT NULL,
        client_id TEXT,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        attachment_json TEXT
      )''');
    await db.execute('CREATE INDEX messages_conv_time ON messages(conversation_id, created_at)');
    await db.execute('CREATE INDEX messages_client ON messages(client_id)');
  }

  // ---------------------------------------------------------------- messages

  Map<String, Object?> _row(ChatMessage m) => {
        'id': m.id,
        'conversation_id': m.conversationId,
        'sender_id': m.senderId,
        'type': m.type,
        'body': m.body,
        'client_id': m.clientId,
        'created_at': m.createdAt.millisecondsSinceEpoch,
        'status': m.status.name,
        'attachment_json': m.attachment == null ? null : jsonEncode(m.attachment!.toJson()),
      };

  ChatMessage _fromRow(Map<String, Object?> r) => ChatMessage(
        id: r['id']! as String,
        conversationId: r['conversation_id']! as String,
        senderId: r['sender_id']! as String,
        type: r['type']! as String,
        body: r['body']! as String,
        clientId: r['client_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        status: DeliveryStatus.values.byName(r['status']! as String),
        attachment: r['attachment_json'] == null
            ? null
            : ChatAttachment.fromJson(Map<String, dynamic>.from(jsonDecode(r['attachment_json']! as String) as Map)),
      );

  /// Insert or update by id. If a local optimistic row with the same clientId exists, it is replaced.
  /// Never downgrades a delivered message back to sent, and keeps an existing local file path.
  Future<void> upsert(ChatMessage m) async {
    await db.transaction((tx) async {
      var msg = m;
      final existing = await tx.query('messages', where: 'id = ? OR (client_id IS NOT NULL AND client_id = ?)', whereArgs: [m.id, m.clientId ?? '\u0000']);
      for (final e in existing) {
        final old = _fromRow(e);
        if (old.status == DeliveryStatus.delivered && msg.status == DeliveryStatus.sent) msg = msg.copyWith(status: DeliveryStatus.delivered);
        final oldPath = old.attachment?.localPath;
        if (oldPath != null && msg.attachment != null && msg.attachment!.localPath == null) {
          msg = msg.copyWith(attachment: msg.attachment!.withLocalPath(oldPath));
        }
        await tx.delete('messages', where: 'id = ?', whereArgs: [old.id]);
      }
      await tx.insert('messages', _row(msg), conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.rawUpdate(
        'UPDATE conversations SET updated_at = MAX(updated_at, ?) WHERE id = ?',
        [msg.createdAt.millisecondsSinceEpoch, msg.conversationId],
      );
    });
    _changes.add(m.conversationId);
  }

  Future<bool> has(String id) async => (await db.query('messages', columns: ['id'], where: 'id = ?', whereArgs: [id])).isNotEmpty;

  /// Newest first, optionally strictly older than [before].
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before, int limit = 50}) async {
    final rows = await db.query(
      'messages',
      where: before == null ? 'conversation_id = ?' : 'conversation_id = ? AND created_at < ?',
      whereArgs: before == null ? [conversationId] : [conversationId, before.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> setStatus(String conversationId, String id, DeliveryStatus status) async {
    await db.update('messages', {'status': status.name}, where: 'id = ? OR client_id = ?', whereArgs: [id, id]);
    _changes.add(conversationId);
  }

  Future<void> markDelivered(String conversationId, List<String> ids) async {
    if (ids.isEmpty) return;
    await db.update(
      'messages',
      {'status': DeliveryStatus.delivered.name},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    _changes.add(conversationId);
  }

  /// Sending messages left over from a crash are shown as failed (tap to retry).
  Future<void> failStaleSending() async {
    await db.update('messages', {'status': DeliveryStatus.failed.name}, where: 'status = ?', whereArgs: [DeliveryStatus.sending.name]);
  }

  Future<void> deleteMessage(String conversationId, String id) async {
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
    _changes.add(conversationId);
  }

  // ---------------------------------------------------------------- conversations

  Future<void> upsertConversation(String id, PublicUser peer, {DateTime? peerLastReadAt, DateTime? updatedAt}) async {
    final now = (updatedAt ?? DateTime.now()).millisecondsSinceEpoch;
    await db.rawInsert(
      '''INSERT INTO conversations (id, peer_json, peer_last_read_at, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET peer_json = excluded.peer_json,
           peer_last_read_at = COALESCE(MAX(conversations.peer_last_read_at, excluded.peer_last_read_at), excluded.peer_last_read_at, conversations.peer_last_read_at),
           updated_at = MAX(conversations.updated_at, excluded.updated_at)''',
      [id, jsonEncode(peer.toJson()), peerLastReadAt?.millisecondsSinceEpoch, now],
    );
  }

  Future<void> markRead(String conversationId, DateTime at) async {
    await db.update('conversations', {'last_read_at': at.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [conversationId]);
    _changes.add(conversationId);
  }

  Future<void> setPeerRead(String conversationId, DateTime at) async {
    await db.rawUpdate(
      'UPDATE conversations SET peer_last_read_at = MAX(COALESCE(peer_last_read_at, 0), ?) WHERE id = ?',
      [at.millisecondsSinceEpoch, conversationId],
    );
    _changes.add(conversationId);
  }

  Future<DateTime?> peerLastReadAt(String conversationId) async {
    final r = await db.query('conversations', columns: ['peer_last_read_at'], where: 'id = ?', whereArgs: [conversationId]);
    final v = r.isEmpty ? null : r.first['peer_last_read_at'] as int?;
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  /// Local conversation list: cached peer, last message, unread (peer messages after my last read).
  Future<List<Conversation>> conversations(String meId) async {
    final convs = await db.query('conversations', orderBy: 'updated_at DESC');
    final out = <Conversation>[];
    for (final c in convs) {
      final id = c['id']! as String;
      final last = await messages(id, limit: 1);
      final lastRead = c['last_read_at'] as int? ?? 0;
      final unread = firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM messages WHERE conversation_id = ? AND sender_id <> ? AND type <> 'SYSTEM' AND created_at > ?",
            [id, meId, lastRead],
          )) ??
          0;
      final plr = c['peer_last_read_at'] as int?;
      out.add(Conversation(
        id: id,
        peer: PublicUser.fromJson(Map<String, dynamic>.from(jsonDecode(c['peer_json']! as String) as Map)),
        lastMessage: last.firstOrNull,
        unread: unread,
        peerLastReadAt: plr == null ? null : DateTime.fromMillisecondsSinceEpoch(plr),
        updatedAt: last.firstOrNull?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(c['updated_at']! as int),
      ));
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// All attachment files referenced by messages (for wipe / backup).
  Future<List<String>> localFiles() async {
    final rows = await db.query('messages', columns: ['attachment_json'], where: 'attachment_json IS NOT NULL');
    return [
      for (final r in rows)
        if ((jsonDecode(r['attachment_json']! as String) as Map)['localPath'] case final String p) p,
    ];
  }

  // ---------------------------------------------------------------- backup

  /// Plain JSON backup of conversations + messages (attachment files are not included).
  Future<String> exportJson() async => jsonEncode({
        'format': 'lumi-chat-backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'conversations': await db.query('conversations'),
        'messages': await db.query('messages'),
      });

  /// Merges a backup (existing rows win). Returns the number of messages imported.
  Future<int> importJson(String json) async {
    final d = jsonDecode(json);
    if (d is! Map || d['format'] != 'lumi-chat-backup') throw const FormatException('Not a Lumi backup');
    var n = 0;
    await db.transaction((tx) async {
      for (final c in (d['conversations'] as List)) {
        await tx.insert('conversations', Map<String, Object?>.from(c as Map), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final m in (d['messages'] as List)) {
        final row = Map<String, Object?>.from(m as Map);
        if (row['status'] == DeliveryStatus.sending.name) row['status'] = DeliveryStatus.failed.name;
        n += await tx.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.ignore) > 0 ? 1 : 0;
      }
    });
    for (final c in (d['conversations'] as List)) {
      _changes.add((c as Map)['id'] as String);
    }
    return n;
  }

  Future<void> clear() async {
    await db.delete('messages');
    await db.delete('conversations');
  }

  Future<void> close() async {
    await _changes.close();
    await db.close();
  }
}
