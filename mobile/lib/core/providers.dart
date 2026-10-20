import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/server_config.dart';
import 'network/api_client.dart';
import 'realtime/socket_service.dart';
import 'storage/token_storage.dart';

/// Overridden in main() after tokens are loaded from secure storage.
final tokenStorageProvider = Provider<TokenStorage>((ref) => throw UnimplementedError());

final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(ref.watch(tokenStorageProvider));
  void onServer(String url) => api.baseUrl = url;
  ServerConfig.addListener(onServer);
  ref.onDispose(() => ServerConfig.removeListener(onServer));
  return api;
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final s = SocketService(ref.watch(tokenStorageProvider), ref.watch(apiClientProvider));
  void onServer(String _) => s.switchServer();
  ServerConfig.addListener(onServer);
  ref.onDispose(() {
    ServerConfig.removeListener(onServer);
    s.dispose();
  });
  return s;
});
