import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/chat_models.dart';
import 'local_chat_store.dart';
import 'local_db.dart';

/// Store-and-forward client: pulls queued messages (socket push on connect + REST),
/// saves them and their attachments on the device, then acks so the server deletes them.
class ChatSync {
  ChatSync(this._store, this._socket, this._api, this._meId);
  final LocalChatStore _store;
  final SocketService _socket;
  final ApiClient _api;
  final String _meId;
  final _subs = <StreamSubscription>[];
  bool _pulling = false;

  LocalChatStore get store => _store;

  void start() {
    _subs
      ..add(_socket.on('chat:message').listen((d) => _ingest([d])))
      ..add(_socket.on('chat:pending').listen((d) => _ingest(List<Map>.from(d['items'] as List? ?? const []))))
      ..add(_socket.on('chat:delivered').listen((d) =>
          _store.markDelivered(d['conversationId'] as String, List<String>.from(d['messageIds'] as List? ?? const []))))
      ..add(_socket.on('chat:read').listen((d) {
        if (d['userId'] != _meId) _store.setPeerRead(d['conversationId'] as String, DateTime.parse(d['readAt'] as String));
      }));
    _socket.status.addListener(_onStatus);
    unawaited(pullPending());
  }

  void _onStatus() {
    if (_socket.status.value == SocketStatus.connected) unawaited(pullPending());
  }

  /// REST fallback / catch-up: loops until the server queue is empty.
  Future<void> pullPending() async {
    if (_pulling) return;
    _pulling = true;
    try {
      for (var i = 0; i < 20; i++) {
        final j = await _api.get<Map>('/messages/pending', query: {'limit': 200});
        final items = List<Map>.from(j['items'] as List);
        final acked = await _ingest(items);
        if (j['hasMore'] != true || acked == 0) break;
      }
    } catch (e) {
      debugPrint('pullPending: $e');
    } finally {
      _pulling = false;
    }
  }

  /// Saves messages locally and acks the ones addressed to me. Returns how many were acked.
  Future<int> _ingest(List<Map> raw) async {
    final toAck = <String>[];
    for (final r in raw) {
      final m = ChatMessage.fromJson(Map<String, dynamic>.from(r));
      try {
        final mine = m.senderId == _meId && m.type != 'SYSTEM';
        if (mine) {
          // Echo of my own message: my device already has it (keep local file path / status).
          await _store.upsert(m.copyWith(status: DeliveryStatus.sent));
          continue;
        }
        var msg = m;
        final a = m.attachment;
        if (a != null && !await _store.has(m.id)) {
          msg = m.copyWith(attachment: a.withLocalPath(await _download(m.conversationId, a)));
        }
        await _store.upsert(msg.copyWith(status: DeliveryStatus.delivered));
        toAck.add(m.id);
      } catch (e) {
        // Not acked: the server keeps it and we retry on the next pull.
        debugPrint('ingest ${m.id} failed: $e');
      }
    }
    if (toAck.isNotEmpty) await _ack(toAck);
    return toAck.length;
  }

  Future<String> _download(String conversationId, ChatAttachment a) async {
    final dir = await LocalDb.attachmentsDir(_meId);
    final safe = a.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = p.join(dir.path, conversationId, '${a.id}_$safe');
    await Directory(p.dirname(path)).create(recursive: true);
    await _api.dio.download(a.absoluteUrl, path, options: Options(extra: {'noAuth': true}));
    return path;
  }

  /// Persist bytes I am sending so my copy survives after the server deletes its own.
  Future<String> saveOutgoing(String conversationId, String clientId, PendingMedia m) async {
    final dir = await LocalDb.attachmentsDir(_meId);
    final path = p.join(dir.path, conversationId, '${clientId}_${m.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}');
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsBytes(m.bytes, flush: true);
    return path;
  }

  Future<void> _ack(List<String> ids) async {
    try {
      await _socket.request('chat:ack', {'ids': ids});
    } catch (_) {
      await _api.post('/messages/ack', data: {'ids': ids});
    }
  }

  void dispose() {
    _socket.status.removeListener(_onStatus);
    for (final s in _subs) {
      s.cancel();
    }
  }
}

final chatSyncProvider = FutureProvider<ChatSync?>((ref) async {
  final store = await ref.watch(localChatStoreProvider.future);
  final me = ref.watch(meProvider.select((m) => m?.id));
  if (store == null || me == null) return null;
  final sync = ChatSync(store, ref.read(socketServiceProvider), ref.read(apiClientProvider), me)..start();
  ref.onDispose(sync.dispose);
  return sync;
});
