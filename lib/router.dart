import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/achievements_screen.dart';
import 'screens/breathe_screen.dart';
import 'screens/category_screen.dart';
import 'screens/complete_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/exercise_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meditate_screen.dart';
import 'screens/meditation_player_screen.dart';
import 'screens/movements_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/plan_detail_screen.dart';
import 'screens/plan_ready_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/player_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/session_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'widgets/tab_shell.dart';
import 'widgets/toast.dart';

const _tabRoots = {'/', '/plans', '/meditate', '/history', '/profile'};

/// Fade + rise page transition (web Screen entrance).
CustomTransitionPage<void> _page(GoRouterState s, Widget child, {bool modal = false}) {
  return CustomTransitionPage<void>(
    key: s.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: modal ? 480 : 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, anim, secondary, child) {
      final a = CurvedAnimation(parent: anim, curve: kEase, reverseCurve: Curves.easeIn);
      if (modal) {
        return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a), child: child);
      }
      return FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(a), child: child),
      );
    },
  );
}

GoRouter buildRouter(AppState app) {
  return GoRouter(
    navigatorKey: Toast.navigatorKey,
    initialLocation: '/',
    refreshListenable: app,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!app.onboarded && _tabRoots.contains(loc)) return '/welcome';
      if (app.onboarded && (loc == '/welcome' || loc == '/onboarding')) return '/';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', pageBuilder: (c, s) => NoTransitionPage(child: const HomeScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/plans', pageBuilder: (c, s) => NoTransitionPage(child: PlansScreen(initialTab: s.uri.queryParameters['tab'] ?? 'programs')))]),
          StatefulShellBranch(routes: [GoRoute(path: '/meditate', pageBuilder: (c, s) => const NoTransitionPage(child: MeditateScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', pageBuilder: (c, s) => const NoTransitionPage(child: HistoryScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', pageBuilder: (c, s) => const NoTransitionPage(child: ProfileScreen()))]),
        ],
      ),
      GoRoute(path: '/welcome', pageBuilder: (c, s) => _page(s, const WelcomeScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
      GoRoute(path: '/plan-ready', pageBuilder: (c, s) => _page(s, const PlanReadyScreen())),
      GoRoute(path: '/paywall', pageBuilder: (c, s) => _page(s, PaywallScreen(from: s.uri.queryParameters['from'] ?? 'app'), modal: true)),
      GoRoute(path: '/plan/:id', pageBuilder: (c, s) => _page(s, PlanDetailScreen(planId: s.pathParameters['id']!))),
      GoRoute(path: '/category/:id', pageBuilder: (c, s) => _page(s, CategoryScreen(categoryId: s.pathParameters['id']!))),
      GoRoute(path: '/movements', pageBuilder: (c, s) => _page(s, MovementsScreen(initialCategory: s.uri.queryParameters['category']))),
      GoRoute(path: '/exercise/:id', pageBuilder: (c, s) => _page(s, ExerciseScreen(exerciseId: s.pathParameters['id']!))),
      GoRoute(path: '/session/:id', pageBuilder: (c, s) => _page(s, SessionScreen(sessionId: s.pathParameters['id']!))),
      GoRoute(path: '/player/:id', pageBuilder: (c, s) => _page(s, PlayerScreen(sessionId: s.pathParameters['id']!), modal: true)),
      GoRoute(path: '/complete', pageBuilder: (c, s) => _page(s, CompleteScreen(entryId: s.uri.queryParameters['id'] ?? ''))),
      GoRoute(path: '/meditation/:id', pageBuilder: (c, s) => _page(s, MeditationPlayerScreen(meditationId: s.pathParameters['id']!), modal: true)),
      GoRoute(path: '/breathe', pageBuilder: (c, s) => _page(s, const BreatheScreen(), modal: true)),
      GoRoute(path: '/achievements', pageBuilder: (c, s) => _page(s, const AchievementsScreen())),
      GoRoute(path: '/settings', pageBuilder: (c, s) => _page(s, const SettingsScreen())),
      GoRoute(path: '/reminders', pageBuilder: (c, s) => _page(s, const RemindersScreen())),
      GoRoute(path: '/edit-profile', pageBuilder: (c, s) => _page(s, const EditProfileScreen())),
    ],
  );
}
