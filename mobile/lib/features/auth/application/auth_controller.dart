import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

sealed class AuthState {
  const AuthState();
}

class AuthRestoring extends AuthState {
  const AuthRestoring();
}

/// Session exists but the server could not be reached at startup.
class AuthOffline extends AuthState {
  const AuthOffline(this.error);
  final Object error;
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticated extends AuthState {
  const Authenticated(this.me);
  final Me me;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: current user or null.
final meProvider = Provider<Me?>((ref) {
  final s = ref.watch(authControllerProvider);
  return s is Authenticated ? s.me : null;
});

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    final api = ref.read(apiClientProvider);
    api.onSessionExpired = _expired;
    api.onTokensRefreshed = (_) {};
    if (!ref.read(tokenStorageProvider).hasSession) return const Unauthenticated();
    Future.microtask(restore);
    return const AuthRestoring();
  }

  Future<void> restore() async {
    state = const AuthRestoring();
    try {
      _signedIn(await _repo.me());
    } on ApiException catch (e) {
      if (e.isNetwork) {
        state = AuthOffline(e);
      } else {
        await ref.read(tokenStorageProvider).clear();
        state = const Unauthenticated();
      }
    }
  }

  Future<CodeSent> register(String email, String password, String locale) => _repo.register(email, password, locale);
  Future<CodeSent> resend(String email) => _repo.resend(email);
  Future<CodeSent> forgot(String email) => _repo.forgot(email);

  Future<void> verifyEmail(String email, String code) async => _signedIn(await _repo.verifyEmail(email, code));
  Future<void> login(String email, String password) async => _signedIn(await _repo.login(email, password));
  Future<void> resetPassword(String email, String code, String pw) async => _signedIn(await _repo.resetPassword(email, code, pw));

  void updateMe(Me me) => state = Authenticated(me);

  Future<void> logout() async {
    ref.read(socketServiceProvider).disconnect();
    await _repo.logout();
    state = const Unauthenticated();
  }

  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    ref.read(socketServiceProvider).disconnect();
    state = const Unauthenticated();
  }

  void _signedIn(Me me) {
    state = Authenticated(me);
    ref.read(socketServiceProvider).connect();
  }

  void _expired() {
    ref.read(socketServiceProvider).disconnect();
    state = const Unauthenticated();
  }
}
