import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../profile/presentation/user_profile_sheet.dart';
import '../application/feed_controller.dart';
import '../domain/post.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(feedControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(feedControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.pink,
          onPressed: () => _compose(context),
          icon: const Icon(Icons.edit_rounded),
          label: Text(l.newPost),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [Text(l.feedTitle, style: Theme.of(context).textTheme.headlineMedium)]),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(feedControllerProvider)),
              data: (s) => RefreshIndicator(
                onRefresh: ref.read(feedControllerProvider.notifier).refresh,
                child: s.items.isEmpty
                    ? ListView(children: [SizedBox(height: 420, child: EmptyView(emoji: '🌙', title: l.feedEmpty, subtitle: l.feedEmptyHint))])
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
                        itemCount: s.items.length + (s.loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => i == s.items.length ? const LoadingView() : _PostCard(post: s.items[i]),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _ComposeSheet());
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider).languageCode;
    final ctrl = ref.read(feedControllerProvider.notifier);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: post.mine
                ? null
                : () async {
                    final blocked = await showUserProfileSheet(context, post.author);
                    if (blocked == true) ctrl.refresh();
                  },
            child: LumiAvatar(avatarId: post.author.avatarId, size: 42),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.author.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                [if (post.author.age != null) l.ageYears(post.author.age!), formatRelative(post.createdAt, locale)].join(' · '),
                style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ]),
          ),
          if (post.mine)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () async {
                if (await confirmDialog(context, '${l.deletePost}?', confirm: l.deletePost, danger: true)) await ctrl.remove(post.id);
              },
            ),
        ]),
        const SizedBox(height: 12),
        Text(post.body, style: const TextStyle(fontSize: 15, height: 1.45)),
        const SizedBox(height: 10),
        Row(children: [
          _LikeButton(liked: post.likedByMe, onTap: () => ctrl.toggleLike(post)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a), child: c),
            child: Text('${post.likeCount}', key: ValueKey(post.likeCount), style: const TextStyle(color: AppColors.textMuted)),
          ),
        ]),
      ]),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.onTap});
  final bool liked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(liked),
            color: liked ? AppColors.pink : AppColors.textMuted,
          ),
        ),
      );
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet();
  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _c = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    setState(() => _posting = true);
    try {
      await ref.read(feedControllerProvider.notifier).create(_c.text.trim());
      if (!mounted) return;
      final l = context.l10n;
      Navigator.pop(context);
      showSnack(context, l.posted);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.newPost, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          maxLength: 1000,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: l.postHint),
        ),
        const SizedBox(height: 8),
        GradientButton(label: l.post, loading: _posting, onPressed: _c.text.trim().isEmpty ? null : _post),
      ]),
    );
  }
}
