/// Full Material 3 dark theme for DEVA.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface:          AppColors.background,
      surfaceContainer: AppColors.surface,
      primary:          AppColors.cyanPrimary,
      secondary:        AppColors.purpleAccent,
      tertiary:         AppColors.greenAccent,
      error:            AppColors.redError,
      onSurface:        AppColors.textPrimary,
      onPrimary:        AppColors.background,
    ),
    textTheme: AppTypography.textTheme,

    // ── AppBar ────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppTypography.headingSmall.copyWith(
        color: AppColors.textPrimary,
        letterSpacing: 3,
      ),
      iconTheme: const IconThemeData(color: AppColors.cyanPrimary),
    ),

    // ── BottomNavigationBar ───────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface.withOpacity(0.8),
      indicatorColor: AppColors.cyanPrimary.withOpacity(0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.cyanPrimary, size: 24);
        }
        return const IconThemeData(color: AppColors.textHint, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelMedium.copyWith(
            color: AppColors.cyanPrimary,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.labelMedium;
      }),
    ),

    // ── Divider ───────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.glassBorder,
      thickness: 0.5,
    ),

    // ── Icon ──────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.cyanPrimary, size: 22),

    // ── Card ──────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
      ),
    ),

    // ── TextButton ────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyanPrimary,
        textStyle: AppTypography.labelLarge,
      ),
    ),

    // ── ElevatedButton ───────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyanPrimary.withOpacity(0.15),
        foregroundColor: AppColors.cyanPrimary,
        side: const BorderSide(color: AppColors.cyanPrimary, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: AppTypography.labelLarge,
        elevation: 0,
      ),
    ),

    // ── TextField ─────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cyanPrimary, width: 1.5),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
      labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── Switch ────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.cyanPrimary : AppColors.textHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.cyanPrimary.withOpacity(0.3)
              : AppColors.surface),
    ),

    // ── Slider ────────────────────────────────────────────────────────
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.cyanPrimary,
      thumbColor: AppColors.cyanPrimary,
      inactiveTrackColor: AppColors.glassBorder,
      overlayColor: Color(0x2200D4FF),
    ),
  );
}
