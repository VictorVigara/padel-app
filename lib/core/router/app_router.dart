import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:padel_app/core/network/supabase_client.dart';
import 'package:padel_app/features/auth/presentation/screens/login_screen.dart';
import 'package:padel_app/features/auth/presentation/screens/register_screen.dart';
import 'package:padel_app/features/match/presentation/screens/match_detail_screen.dart';
import 'package:padel_app/features/match/presentation/screens/match_form_screen.dart';
import 'package:padel_app/features/match/presentation/screens/match_history_screen.dart';
import 'package:padel_app/features/statistics/presentation/screens/stats_dashboard_screen.dart';
import 'package:padel_app/features/player_profile/presentation/screens/edit_profile_screen.dart';
import 'package:padel_app/features/player_profile/presentation/screens/profile_screen.dart';
import 'package:padel_app/features/player_profile/presentation/screens/profile_setup_screen.dart';
import 'package:padel_app/core/widgets/app_shell.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/matches',
    redirect: (context, state) {
      final isLoggedIn = SupabaseConfig.isConfigured &&
          SupabaseConfig.currentUser != null;
      final isAuthRoute = state.uri.path == '/login' ||
          state.uri.path == '/register';

      if (!SupabaseConfig.isConfigured) return null;

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/matches';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/matches',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MatchHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/statistics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StatsDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/matches/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MatchFormScreen(),
      ),
      GoRoute(
        path: '/matches/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MatchDetailScreen(
          matchId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/matches/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MatchFormScreen(
          matchId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
    ],
  );
}
