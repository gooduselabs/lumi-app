import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

class AuthRepository {
  AuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStorage _tokens;

  Future<CodeSent> register(String email, String password, String locale) async =>
      CodeSent.fromJson(await _api.post('/auth/register', data: {'email': email, 'password': password, 'locale': locale}, auth: false));

  Future<CodeSent> resend(String email) async =>
      CodeSent.fromJson(await _api.post('/auth/resend-code', data: {'email': email}, auth: false));

  Future<CodeSent> forgot(String email) async =>
      CodeSent.fromJson(await _api.post('/auth/forgot-password', data: {'email': email}, auth: false));

  Future<Me> verifyEmail(String email, String code) =>
      _session(_api.post('/auth/verify-email', data: {'email': email, 'code': code}, auth: false));

  Future<Me> login(String email, String password) =>
      _session(_api.post('/auth/login', data: {'email': email, 'password': password}, auth: false));

  Future<Me> resetPassword(String email, String code, String newPassword) => _session(
      _api.post('/auth/reset-password', data: {'email': email, 'code': code, 'newPassword': newPassword}, auth: false));

  Future<Me> me() async => Me.fromJson(await _api.get('/me'));

  Future<void> logout() async {
    final rt = _tokens.refreshToken;
    if (rt != null) {
      try {
        await _api.post('/auth/logout', data: {'refreshToken': rt}, auth: false);
      } catch (_) {/* best effort */}
    }
    await _tokens.clear();
  }

  Future<void> deleteAccount() async {
    await _api.delete('/me');
    await _tokens.clear();
  }

  Future<Me> _session(Future<dynamic> call) async {
    final data = Map<String, dynamic>.from(await call as Map);
    await _tokens.save(data['accessToken'] as String, data['refreshToken'] as String);
    return Me.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
}
