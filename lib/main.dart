import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/router/app_router.dart';
import 'shared/services/secure_storage_service.dart';
import 'shared/services/background_service.dart';
import 'shared/database/database_helper.dart';
import 'core/constants/app_constants.dart';

// Phase 2.3: Register the overlay entry point.
// flutter_overlay_window calls overlayMain() when it needs to draw the overlay.
import 'features/overlay/overlay_entry.dart';

// This annotation must be on a top-level function — it tells the Dart VM
// not to tree-shake overlayMain() even though it's not called from main().
@pragma('vm:entry-point')
// ignore: unused_element
void _overlayEntryPoint() => overlayMain();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation — DEVA is portrait-first
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Immersive dark system UI (transparent status bar, dark icons)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Warm up local encrypted SQLite database
  // Kick off heavy initialization after the app is running so we
  // don't delay first frame / time-to-interactive.
  // Database and background service will initialize asynchronously.

  // Check if first launch (needs onboarding)
  final onboardingDone =
      await SecureStorageService.instance.isOnboardingComplete();

  runApp(
    ProviderScope(
      child: DevaApp(showOnboarding: !onboardingDone),
    ),
  );

  // Perform non-blocking warm-up tasks after launching the UI.
  Future.microtask(() async {
    try {
      await DatabaseHelper.instance.database;
    } catch (e) {
      // Defensive: log but don't crash the app during warm-up
      // (use debugPrint to keep dependency surface minimal)
      debugPrint('[Main] DB warm-up failed: $e');
    }

    try {
      await initializeBackgroundService();
    } catch (e) {
      debugPrint('[Main] Background service init failed: $e');
    }
  });
}

class DevaApp extends ConsumerWidget {
  final bool showOnboarding;
  const DevaApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Redirect to onboarding if first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showOnboarding) router.go(Routes.onboarding);
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Prevent system font scaling from breaking the UI layout
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
          ),
        ),
        child: child!,
      ),
    );
  }
}
