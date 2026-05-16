/// GoRouter navigation setup for DEVA.
/// Uses a simple Provider (no code generation needed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/shell/presentation/shell_screen.dart';

/// Route path constants — never use raw strings in code.
class Routes {
  Routes._();
  static const String assistant  = '/assistant';
  static const String history    = '/history';
  static const String settings   = '/settings';
  static const String onboarding = '/onboarding';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.assistant,
    debugLogDiagnostics: false,
    routes: [
      // Onboarding — shown once on first launch, no shell/nav bar
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),

      // Shell route wraps the main screens with the glass bottom nav bar
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.assistant,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AssistantScreen(),
            ),
          ),
          GoRoute(
            path: Routes.history,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Center(
        child: Text(
          'Page not found',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
