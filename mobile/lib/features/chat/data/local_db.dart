import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import '../../auth/application/auth_controller.dart';
import 'local_chat_store.dart';

/// Per-user SQLCipher database + attachment folder in the app documents dir.
/// The 256-bit key is generated on first use and kept in the Keychain / Android Keystore.
class LocalDb {
  const LocalDb._();
  static const _secure = FlutterSecureStorage();
  static String _keyName(String uid) => 'lumi.db.key.$uid';

  static Future<Directory> userDir(String uid) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'lumi', uid));
  }

  static Future<Directory> attachmentsDir(String uid) async {
    final d = Directory(p.join((await userDir(uid)).path, 'attachments'));
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  static Future<String> _key(String uid) async {
    final existing = await _secure.read(key: _keyName(uid));
    if (existing != null) return existing;
    final r = Random.secure();
    final key = base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256)));
    await _secure.write(key: _keyName(uid), value: key);
    return key;
  }

  static Future<LocalChatStore> open(String uid) async {
    final dir = await userDir(uid);
    if (!dir.existsSync()) await dir.create(recursive: true);
    final db = await cipher.openDatabase(
      p.join(dir.path, 'chat.db'),
      password: await _key(uid),
      version: LocalChatStore.schemaVersion,
      onCreate: LocalChatStore.createSchema,
    );
    final store = LocalChatStore(db);
    await store.failStaleSending();
    return store;
  }

  /// Deletes the database, every downloaded attachment and the encryption key.
  static Future<void> wipe(String uid) async {
    final dir = await userDir(uid);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await _secure.delete(key: _keyName(uid));
  }
}

/// The signed-in user's local chat store (null while logged out).
final localChatStoreProvider = FutureProvider<LocalChatStore?>((ref) async {
  final uid = ref.watch(meProvider.select((m) => m?.id));
  if (uid == null) return null;
  final store = await LocalDb.open(uid);
  ref.onDispose(() => store.close());
  return store;
});
