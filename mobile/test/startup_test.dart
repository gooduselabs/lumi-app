import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/config/env.dart';
import 'package:lumi/core/config/server_config.dart';
import 'package:lumi/core/network/api_client.dart';
import 'package:lumi/core/storage/token_storage.dart';
import 'package:lumi/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage whose reads never complete (a wedged keystore).
class _HangingStorage extends FlutterSecureStorage {
  const _HangingStorage();
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) =>
      Completer<String?>().future;
}

void main() {
  setUp(() {
    ServerConfig.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  group('ServerConfig', () {
    test('normalizes and validates URLs', () {
      expect(ServerConfig.normalize('192.168.1.10:3000'), 'http://192.168.1.10:3000');
      expect(ServerConfig.normalize(' https://api.lumi.app/ '), 'https://api.lumi.app');
      expect(ServerConfig.normalize('https://x.io/api/v1//'), 'https://x.io/api/v1');
      for (final bad in ['', 'ftp://x.io', 'http://', 'http://a b', 'http://x.io?q=1', 'http://u:p@x.io', 'http://x.io:99999']) {
        expect(ServerConfig.normalize(bad), isNull, reason: bad);
      }
    });

    test('persists, notifies listeners and resets to the build default', () async {
      final prefs = await SharedPreferences.getInstance();
      final seen = <String>[];
      ServerConfig.addListener(seen.add);
      await ServerConfig.save(prefs, '10.0.0.5:3000');
      expect(ServerConfig.current, 'http://10.0.0.5:3000');
      expect(prefs.getString(ServerConfig.prefsKey), 'http://10.0.0.5:3000');
      expect(() => ServerConfig.save(prefs, 'not a url'), throwsFormatException);

      ServerConfig.debugReset();
      ServerConfig.load(prefs);
      expect(ServerConfig.current, 'http://10.0.0.5:3000');

      await ServerConfig.save(prefs, null);
      expect(ServerConfig.current, Env.apiBaseUrl);
      expect(seen, ['http://10.0.0.5:3000']);
    });

    test('ApiClient follows the configured server and uses short timeouts', () {
      final api = ApiClient(TokenStorage());
      expect(api.baseUrl, Env.apiBaseUrl);
      expect(api.dio.options.connectTimeout, const Duration(seconds: 8));
      api.baseUrl = 'http://10.0.0.9:3000';
      expect(api.dio.options.baseUrl, 'http://10.0.0.9:3000');
    });
  });

  test('a wedged keystore times out and the app starts signed out', () async {
    final tokens = TokenStorage(const _HangingStorage());
    final sw = Stopwatch()..start();
    await tokens.load(timeout: const Duration(milliseconds: 100));
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    expect(tokens.hasSession, isFalse);
  });

  test('bootstrap applies the saved server address', () async {
    SharedPreferences.setMockInitialValues({ServerConfig.prefsKey: 'http://192.168.0.7:3000'});
    final r = await bootstrap(tokens: TokenStorage(const _HangingStorage()));
    expect(ServerConfig.current, 'http://192.168.0.7:3000');
    expect(r.tokens.hasSession, isFalse);
  }, timeout: const Timeout(Duration(seconds: 20)));

  testWidgets('first frame renders immediately, before startup work finishes', (tester) async {
    final gate = Completer<BootResult>();
    await tester.pumpWidget(LumiBootstrap(boot: () => gate.future, app: const Text('APP', textDirection: TextDirection.ltr)));
    expect(find.byKey(const Key('boot-splash')), findsOneWidget);
    gate.complete(BootResult(await SharedPreferences.getInstance(), TokenStorage()));
    await tester.pump();
    await tester.pump();
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('startup failure shows retry instead of hanging', (tester) async {
    var calls = 0;
    await tester.pumpWidget(LumiBootstrap(
      boot: () async {
        calls++;
        throw TimeoutException('prefs');
      },
      app: const SizedBox(),
    ));
    await tester.pump();
    expect(find.textContaining('Retry'), findsOneWidget);
    await tester.tap(find.textContaining('Retry'));
    await tester.pump();
    expect(calls, 2);
  });
}
