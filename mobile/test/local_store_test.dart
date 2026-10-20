import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/features/auth/domain/user.dart';
import 'package:lumi/features/chat/data/local_chat_store.dart';
import 'package:lumi/features/chat/domain/chat_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ChatMessage msg(String id, String sender, int minute, {String? clientId, DeliveryStatus status = DeliveryStatus.sent, String type = 'TEXT', ChatAttachment? att}) =>
    ChatMessage(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      body: 'body $id',
      type: type,
      clientId: clientId,
      createdAt: DateTime.utc(2026, 10, 20, 10, minute),
      status: status,
      attachment: att,
    );

void main() {
  sqfliteFfiInit();
  late LocalChatStore store;

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: LocalChatStore.schemaVersion, onCreate: LocalChatStore.createSchema, singleInstance: false),
    );
    store = LocalChatStore(db);
    await store.upsertConversation('c1', const PublicUser(id: 'peer', nickname: 'Mai', avatarId: 'a04'));
  });
  tearDown(() => store.close());

  test('stores history newest-first with paging', () async {
    for (var i = 0; i < 5; i++) {
      await store.upsert(msg('m$i', i.isEven ? 'me' : 'peer', i));
    }
    final page = await store.messages('c1', limit: 3);
    expect(page.map((m) => m.id), ['m4', 'm3', 'm2']);
    final older = await store.messages('c1', before: page.last.createdAt, limit: 3);
    expect(older.map((m) => m.id), ['m1', 'm0']);
  });

  test('server copy replaces the optimistic row by clientId, keeps local file, never downgrades delivered', () async {
    const local = ChatAttachment(id: 'cid', kind: 'IMAGE', mimeType: 'image/png', sizeBytes: 3, fileName: 'a.png', url: '', localPath: '/docs/a.png');
    await store.upsert(msg('cid', 'me', 1, clientId: 'cid', status: DeliveryStatus.sending, type: 'IMAGE', att: local));
    const remote = ChatAttachment(id: 'att1', kind: 'IMAGE', mimeType: 'image/png', sizeBytes: 3, fileName: 'a.png', url: '/attachments/att1');
    await store.upsert(msg('srv1', 'me', 1, clientId: 'cid', type: 'IMAGE', att: remote));
    var all = await store.messages('c1');
    expect(all, hasLength(1));
    expect(all.single.id, 'srv1');
    expect(all.single.attachment!.localPath, '/docs/a.png');

    await store.markDelivered('c1', ['srv1']);
    await store.upsert(msg('srv1', 'me', 1, clientId: 'cid', type: 'IMAGE', att: remote)); // late echo
    all = await store.messages('c1');
    expect(all.single.status, DeliveryStatus.delivered);
  });

  test('unread, read receipts and conversation list', () async {
    await store.upsert(msg('a', 'peer', 1));
    await store.upsert(msg('b', 'peer', 2));
    await store.upsert(msg('s', 'peer', 0, type: 'SYSTEM'));
    var list = await store.conversations('me');
    expect(list.single.unread, 2);
    expect(list.single.lastMessage!.id, 'b');
    expect(list.single.peer.nickname, 'Mai');

    await store.markRead('c1', DateTime.utc(2026, 10, 20, 10, 1, 30));
    list = await store.conversations('me');
    expect(list.single.unread, 1);

    await store.setPeerRead('c1', DateTime.utc(2026, 10, 20, 11));
    await store.setPeerRead('c1', DateTime.utc(2026, 10, 20, 9)); // older receipt ignored
    expect(await store.peerLastReadAt('c1'), DateTime.utc(2026, 10, 20, 11).toLocal());
  });

  test('stale sending messages become failed after restart', () async {
    await store.upsert(msg('x', 'me', 1, clientId: 'x', status: DeliveryStatus.sending));
    await store.failStaleSending();
    expect((await store.messages('c1')).single.status, DeliveryStatus.failed);
  });

  test('emits change events per conversation', () async {
    final events = <String>[];
    final sub = store.changes.listen(events.add);
    await store.upsert(msg('e', 'peer', 1));
    await store.markRead('c1', DateTime.now());
    await Future<void>.delayed(Duration.zero);
    expect(events, ['c1', 'c1']);
    await sub.cancel();
  });

  test('export / import backup round-trip', () async {
    await store.upsert(msg('k1', 'peer', 1));
    await store.upsert(msg('k2', 'me', 2));
    final json = await store.exportJson();
    await store.clear();
    expect(await store.messages('c1'), isEmpty);
    expect(await store.importJson(json), 2);
    expect(await store.importJson(json), 0); // idempotent
    expect((await store.conversations('me')).single.lastMessage!.id, 'k2');
    expect(() => store.importJson('{"format":"other"}'), throwsFormatException);
  });
}
