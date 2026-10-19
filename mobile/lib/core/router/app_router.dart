import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/match/domain/match_models.dart';
import '../../features/match/presentation/discover_screen.dart';
import '../../features/match/presentation/match_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/me_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';

const _publicRoutes = {'/welcome', '/login', '/register', '/verify', '/forgot', '/reset'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      switch (auth) {
        case AuthRestoring() || AuthOffline():
          return loc == '/splash' ? null : '/splash';
        case Unauthenticated():
          return _publicRoutes.contains(loc) ? null : '/welcome';
        case Authenticated(:final me):
          if (!me.onboarded) return loc == '/onboarding' ? null : '/onboarding';
          if (_publicRoutes.contains(loc) || loc == '/splash' || loc == '/onboarding') return '/discover';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, s) => VerifyScreen(email: s.uri.queryParameters['email'] ?? '', devCode: s.uri.queryParameters['dev']),
      ),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset',
        builder: (_, s) => ResetPasswordScreen(email: s.uri.queryParameters['email'] ?? '', devCode: s.uri.queryParameters['dev']),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/feed', builder: (_, _) => const FeedScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (_, _) => const MeScreen())]),
        ],
      ),
      GoRoute(
        path: '/match',
        pageBuilder: (_, s) => CustomTransitionPage(
          child: MatchScreen(mode: s.uri.queryParameters['mode'] == 'voice' ? MatchMode.voice : MatchMode.soul),
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 1.05, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
          ),
        ),
      ),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
      GoRoute(path: '/me/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/settings/blocked', builder: (_, _) => const BlockedUsersScreen()),
    ],
  );
});
