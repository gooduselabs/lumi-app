import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/network/api_client.dart';
import 'package:lumi/core/network/api_exception.dart';
import 'package:lumi/core/storage/token_storage.dart';

void main() {
  late ServerSocket silent;
  final held = <Socket>[];

  setUpAll(() async {
    // Accepts TCP connections and never answers: the "half-open server / NAT black hole" case.
    silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    silent.listen(held.add);
  });
  tearDownAll(() async {
    for (final s in held) {
      s.destroy();
    }
    await silent.close();
  });

  test('register against a server that never answers ends with a NETWORK error by the deadline', () async {
    final api = ApiClient(TokenStorage(), baseUrl: 'http://127.0.0.1:${silent.port}')
      ..requestDeadline = const Duration(seconds: 2);
    final sw = Stopwatch()..start();
    await expectLater(
      api.post<Map<String, dynamic>>('/auth/register', data: {'email': 'a@b.c'}, auth: false),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('default timeouts stay short (≤15 s for any auth call)', () {
    final api = ApiClient(TokenStorage());
    expect(api.dio.options.connectTimeout, const Duration(seconds: 8));
    expect(api.requestDeadline, lessThanOrEqualTo(const Duration(seconds: 15)));
  });

  test('a non-JSON reply (e.g. a proxy/interstitial HTML page) becomes an ApiException, not a TypeError', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) => r.response
      ..headers.contentType = ContentType.html
      ..write('<html>warning</html>')
      ..close());
    final api = ApiClient(TokenStorage(), baseUrl: 'http://127.0.0.1:${server.port}');
    await expectLater(
      api.post<Map<String, dynamic>>('/auth/login', data: {}, auth: false),
      throwsA(isA<ApiException>()),
    );
    await server.close(force: true);
  });
}
