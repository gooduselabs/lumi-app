import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';

class FeedState {
  const FeedState(this.items, {this.hasMore = false, this.loadingMore = false});
  final List<Post> items;
  final bool hasMore;
  final bool loadingMore;
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);

class FeedController extends AsyncNotifier<FeedState> {
  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  @override
  Future<FeedState> build() async {
    if (ref.watch(meProvider.select((m) => m?.id)) == null) return const FeedState([]);
    final page = await _repo.list();
    return FeedState(page.items, hasMore: page.hasMore);
  }

  Future<void> refresh() async {
    final page = await _repo.list();
    state = AsyncData(FeedState(page.items, hasMore: page.hasMore));
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore || s.items.isEmpty) return;
    state = AsyncData(FeedState(s.items, hasMore: s.hasMore, loadingMore: true));
    try {
      final page = await _repo.list(before: s.items.last.createdAt);
      state = AsyncData(FeedState([...s.items, ...page.items], hasMore: page.hasMore));
    } catch (_) {
      state = AsyncData(FeedState(s.items, hasMore: s.hasMore));
    }
  }

  Future<void> create(String body) async {
    final p = await _repo.create(body);
    final s = state.value;
    state = AsyncData(FeedState([p, ...?s?.items], hasMore: s?.hasMore ?? false));
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    final s = state.value!;
    state = AsyncData(FeedState(s.items.where((p) => p.id != id).toList(), hasMore: s.hasMore));
  }

  /// Optimistic like toggle with rollback.
  Future<void> toggleLike(Post post) async {
    final like = !post.likedByMe;
    _patch(post.id, (p) => p.copyWith(likedByMe: like, likeCount: p.likeCount + (like ? 1 : -1)));
    try {
      await _repo.like(post.id, like);
    } catch (_) {
      _patch(post.id, (_) => post);
    }
  }

  void _patch(String id, Post Function(Post) f) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(FeedState([for (final p in s.items) p.id == id ? f(p) : p], hasMore: s.hasMore, loadingMore: s.loadingMore));
  }
}
