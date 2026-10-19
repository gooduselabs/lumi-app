import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/post.dart';

final feedRepositoryProvider = Provider((ref) => FeedRepository(ref.watch(apiClientProvider)));

class FeedRepository {
  FeedRepository(this._api);
  final ApiClient _api;

  Future<({List<Post> items, bool hasMore})> list({DateTime? before}) async {
    final j = await _api.get<Map>('/posts', query: {'limit': 20, if (before != null) 'before': before.toUtc().toIso8601String()});
    return (
      items: (j['items'] as List).map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      hasMore: j['hasMore'] == true,
    );
  }

  Future<Post> create(String body) async => Post.fromJson(await _api.post('/posts', data: {'body': body}));
  Future<void> remove(String id) => _api.delete('/posts/$id');
  Future<void> like(String id, bool like) => like ? _api.post('/posts/$id/like') : _api.delete('/posts/$id/like');
}
