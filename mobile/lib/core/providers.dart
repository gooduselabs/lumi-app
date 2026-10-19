import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'realtime/socket_service.dart';
import 'storage/token_storage.dart';

/// Overridden in main() after tokens are loaded from secure storage.
final tokenStorageProvider = Provider<TokenStorage>((ref) => throw UnimplementedError());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));

final socketServiceProvider = Provider<SocketService>((ref) {
  final s = SocketService(ref.watch(tokenStorageProvider), ref.watch(apiClientProvider));
  ref.onDispose(s.dispose);
  return s;
});
