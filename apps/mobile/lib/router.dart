import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'data/models.dart';
import 'features/account/account_screen.dart';
import 'features/account/edit_pro_profile_screen.dart';
import 'features/account/my_services_screen.dart';
import 'features/account/settings_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/conversations_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/home/home_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/pro/pro_profile_screen.dart';
import 'features/requests/my_requests_screen.dart';
import 'features/requests/request_detail_screen.dart';
import 'features/requests/request_form_screen.dart';
import 'features/search/search_screen.dart';
import 'features/shell/main_shell.dart';

const _authRoutes = {'/welcome', '/login', '/otp'};
const _guestBlocked = [
  '/requests', '/request/', '/chat', '/favorites', '/notifications', '/settings', '/pro-edit', '/my-services',
];

String? _redirect(BuildContext context, GoRouterState state) {
  final s = Session.instance;
  final loc = state.matchedLocation;
  if (!s.initialized) return loc == '/splash' ? null : '/splash';

  if (!s.isSignedIn) {
    if (!s.onboardingSeen && loc != '/welcome') return '/welcome';
    if (loc == '/splash' || loc == '/setup' || loc == '/suspended') return '/home';
    if (_guestBlocked.any(loc.startsWith)) return '/login';
    return null;
  }
  if (s.isSuspended) return loc == '/suspended' ? null : '/suspended';
  if (s.needsSetup) return (loc == '/setup' || loc == '/about') ? null : '/setup';
  if (_authRoutes.contains(loc) || loc == '/splash' || loc == '/setup' || loc == '/suspended') return '/home';
  return null;
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Session.instance,
    redirect: _redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (_, s) => OtpScreen(email: s.extra as String? ?? '')),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/suspended', builder: (_, __) => const SuspendedScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (_, s) => SearchScreen(
                key: ValueKey(s.uri.query),
                initialCategoryId: s.uri.queryParameters['category'],
                initialQuery: s.uri.queryParameters['q'],
                nearMe: s.uri.queryParameters['near'] == '1',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (_, __) => const ConversationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, __) => const AccountScreen())]),
        ],
      ),
      GoRoute(path: '/pro/:id', builder: (_, s) => ProProfileScreen(proId: s.pathParameters['id']!)),
      GoRoute(
        path: '/request/new',
        builder: (_, s) {
          final extra = (s.extra as Map<String, dynamic>?) ?? const {};
          return RequestFormScreen(
            proId: extra['proId'] as String,
            proName: extra['proName'] as String? ?? '',
            service: extra['service'] as ProService?,
          );
        },
      ),
      GoRoute(path: '/request/sent', builder: (_, s) => RequestSentScreen(requestId: s.extra as String?)),
      GoRoute(path: '/requests', builder: (_, __) => const MyRequestsScreen()),
      GoRoute(path: '/requests/:id', builder: (_, s) => RequestDetailScreen(requestId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!)),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/pro-edit', builder: (_, __) => const EditProProfileScreen()),
      GoRoute(path: '/my-services', builder: (_, __) => const MyServicesScreen()),
      GoRoute(path: '/my-services/edit', builder: (_, s) => ServiceFormScreen(service: s.extra as ProService?)),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    ],
  );
}
