import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'core/transitions.dart';
import 'data/models.dart';
import 'features/account/account_screen.dart';
import 'features/account/edit_pro_profile_screen.dart';
import 'features/account/my_services_screen.dart';
import 'features/account/settings_screen.dart';
import 'features/account/verification_screen.dart';
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

const _authRoutes = {'/welcome', '/login', '/signup', '/otp', '/forgot-password'};

/// L'écran de démarrage reste visible au moins 1,6 s (logo + front de mer animé).
final _splashDone = ValueNotifier<bool>(false);

String? _redirect(BuildContext context, GoRouterState state) {
  final s = Session.instance;
  final loc = state.matchedLocation;
  if (!s.initialized || !_splashDone.value) return loc == '/splash' ? null : '/splash';

  // Compte obligatoire : sans connexion, seuls l'accueil de présentation, la connexion et « À propos » sont accessibles.
  if (!s.isSignedIn) {
    if (!s.onboardingSeen) return loc == '/welcome' ? null : '/welcome';
    if (_authRoutes.contains(loc) || loc == '/about') return null;
    return '/login';
  }
  if (s.isSuspended) return loc == '/suspended' ? null : '/suspended';
  if (s.needsSetup) return (loc == '/setup' || loc == '/about') ? null : '/setup';
  if (_authRoutes.contains(loc) || loc == '/splash' || loc == '/setup' || loc == '/suspended') return '/home';
  return null;
}

GoRouter buildRouter() {
  Future.delayed(const Duration(milliseconds: 1600), () => _splashDone.value = true);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([Session.instance, _splashDone]),
    redirect: _redirect,
    routes: [
      GoRoute(path: '/splash', pageBuilder: (_, st) => motionPage(st, const SplashScreen(), Motion.fade)),
      GoRoute(path: '/welcome', pageBuilder: (_, st) => motionPage(st, const OnboardingScreen(), Motion.fade)),
      GoRoute(path: '/login', pageBuilder: (_, st) => motionPage(st, const LoginScreen(), Motion.depth)),
      GoRoute(
        path: '/otp',
        pageBuilder: (_, s) {
          final x = s.extra;
          final email = x is Map ? x['email'] as String? ?? '' : (x as String? ?? '');
          final mode = x is Map ? x['mode'] as String? ?? 'login' : 'login';
          return motionPage(s, OtpScreen(email: email, mode: mode), Motion.slide);
        },
      ),
      GoRoute(path: '/signup', pageBuilder: (_, st) => motionPage(st, const SignupScreen(), Motion.slide)),
      GoRoute(path: '/forgot-password', pageBuilder: (_, st) => motionPage(st, const ForgotPasswordScreen(), Motion.slide)),
      GoRoute(path: '/new-password', pageBuilder: (_, st) => motionPage(st, const NewPasswordScreen(), Motion.depth)),
      GoRoute(path: '/setup', pageBuilder: (_, st) => motionPage(st, const SetupScreen(), Motion.depth)),
      GoRoute(path: '/suspended', pageBuilder: (_, st) => motionPage(st, const SuspendedScreen(), Motion.fade)),
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
      GoRoute(path: '/pro/:id', pageBuilder: (_, s) => motionPage(s, ProProfileScreen(proId: s.pathParameters['id']!), Motion.zoom)),
      GoRoute(
        path: '/request/new',
        pageBuilder: (_, s) {
          final extra = (s.extra as Map<String, dynamic>?) ?? const {};
          return motionPage(
            s,
            RequestFormScreen(
              proId: extra['proId'] as String,
              proName: extra['proName'] as String? ?? '',
              service: extra['service'] as ProService?,
            ),
            Motion.sheet,
          );
        },
      ),
      GoRoute(path: '/request/sent', pageBuilder: (_, s) => motionPage(s, RequestSentScreen(requestId: s.extra as String?), Motion.depth)),
      GoRoute(path: '/requests', pageBuilder: (_, st) => motionPage(st, const MyRequestsScreen(), Motion.fadeThrough)),
      GoRoute(path: '/requests/:id', pageBuilder: (_, s) => motionPage(s, RequestDetailScreen(requestId: s.pathParameters['id']!), Motion.slide)),
      GoRoute(path: '/chat/:id', pageBuilder: (_, s) => motionPage(s, ChatScreen(conversationId: s.pathParameters['id']!), Motion.slide)),
      GoRoute(path: '/favorites', pageBuilder: (_, st) => motionPage(st, const FavoritesScreen(), Motion.fadeThrough)),
      GoRoute(path: '/notifications', pageBuilder: (_, st) => motionPage(st, const NotificationsScreen(), Motion.fadeThrough)),
      GoRoute(path: '/settings', pageBuilder: (_, st) => motionPage(st, const SettingsScreen(), Motion.fadeThrough)),
      GoRoute(path: '/categories', pageBuilder: (_, st) => motionPage(st, const CategoriesScreen(), Motion.fadeThrough)),
      GoRoute(path: '/verification', pageBuilder: (_, st) => motionPage(st, const VerificationScreen(), Motion.sheet)),
      GoRoute(path: '/premium', pageBuilder: (_, st) => motionPage(st, const PremiumScreen(), Motion.zoom)),
      GoRoute(path: '/pro-dashboard', pageBuilder: (_, st) => motionPage(st, const ProDashboard(), Motion.zoom)),
      GoRoute(path: '/pro-edit', pageBuilder: (_, st) => motionPage(st, const EditProProfileScreen(), Motion.sheet)),
      GoRoute(path: '/my-services', pageBuilder: (_, st) => motionPage(st, const MyServicesScreen(), Motion.fadeThrough)),
      GoRoute(path: '/my-services/edit', pageBuilder: (_, s) => motionPage(s, ServiceFormScreen(service: s.extra as ProService?), Motion.sheet)),
      GoRoute(path: '/about', pageBuilder: (_, st) => motionPage(st, const AboutScreen(), Motion.fadeThrough)),
    ],
  );
}
