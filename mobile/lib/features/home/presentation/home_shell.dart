import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/providers.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../call/application/call_controller.dart';
import '../../chat/application/conversations_controller.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref.watch(totalUnreadProvider);
    final socket = ref.watch(socketServiceProvider);
    // Incoming friend call -> full-screen call UI.
    ref.listen(callControllerProvider.select((c) => c.phase), (prev, next) {
      if (next == CallPhase.incoming && prev != CallPhase.incoming) context.push('/call');
    });
    final items = [
      (Icons.explore_outlined, Icons.explore_rounded, l.tabDiscover),
      (Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, l.tabFeed),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, l.tabChats),
      (Icons.person_outline_rounded, Icons.person_rounded, l.tabMe),
    ];
    return Scaffold(
      extendBody: true,
      body: Column(children: [
        ValueListenableBuilder<SocketStatus>(
          valueListenable: socket.status,
          builder: (_, s, _) => AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: s == SocketStatus.connecting
                ? Container(
                    width: double.infinity,
                    color: AppColors.amber.withValues(alpha: 0.15),
                    padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 4, bottom: 4),
                    child: Text(l.connecting, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.amber, fontSize: 12)),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        Expanded(child: shell),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.stroke),
                ),
                child: Row(children: [
                  for (final (i, it) in items.indexed)
                    Expanded(
                      child: _NavItem(
                        icon: it.$1,
                        activeIcon: it.$2,
                        label: it.$3,
                        selected: shell.currentIndex == i,
                        badge: i == 2 ? unread : 0,
                        onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap, this.badge = 0});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Badge(
          isLabelVisible: badge > 0,
          backgroundColor: AppColors.pink,
          label: Text(badge > 99 ? '99+' : '$badge'),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected
                ? ShaderMask(
                    key: const ValueKey(1),
                    shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
                    child: Icon(activeIcon, color: Colors.white, size: 26),
                  )
                : Icon(icon, key: const ValueKey(0), color: AppColors.textMuted, size: 24),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.text : AppColors.textMuted,
          ),
          child: Text(label),
        ),
      ]),
    );
  }
}
