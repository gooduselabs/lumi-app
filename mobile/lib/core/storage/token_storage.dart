import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists tokens in the platform keystore/keychain and keeps a memory cache.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _kAccess = 'lumi.access';
  static const _kRefresh = 'lumi.refresh';

  String? _access;
  String? _refresh;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null;

  /// Never blocks startup: a slow or broken keystore times out and the app starts signed out.
  Future<void> load({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final values = await Future.wait([_storage.read(key: _kAccess), _storage.read(key: _kRefresh)]).timeout(timeout);
      _access = values[0];
      _refresh = values[1];
    } on TimeoutException {
      _access = null;
      _refresh = null;
    } catch (_) {
      // Corrupted keystore (e.g. after restore): start clean.
      _access = null;
      _refresh = null;
      unawaited(clear().catchError((_) {}));
    }
  }

  Future<void> save(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
