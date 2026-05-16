/// App-wide color palette for DEVA.
/// Dark, futuristic, neon aesthetic — premium glassmorphism UI.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Background layers ──────────────────────────────────────────────────
  static const Color background     = Color(0xFF050A14);  // Deep space black
  static const Color surface        = Color(0xFF0D1526);  // Card surface
  static const Color surfaceHighlight = Color(0xFF132038); // Elevated surface

  // ── Neon accent palette ────────────────────────────────────────────────
  static const Color cyanPrimary    = Color(0xFF00D4FF);  // Avatar idle / speaking
  static const Color cyanGlow       = Color(0xFF00A8CC);  // Softer cyan
  static const Color purpleAccent   = Color(0xFFA855F7);  // Processing state
  static const Color greenAccent    = Color(0xFF00FF88);  // Listening / success
  static const Color goldAccent     = Color(0xFFFFD700);  // Greeting state
  static const Color redError       = Color(0xFFEF4444);  // Error state

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFE8F4FF);
  static const Color textSecondary  = Color(0xFF7A9BC2);
  static const Color textHint       = Color(0xFF3D5A7A);

  // ── Glassmorphism helpers ─────────────────────────────────────────────
  static const Color glassBorder    = Color(0x2200D4FF);   // Cyan with 13% opacity
  static const Color glassWhite     = Color(0x0DFFFFFF);   // White with 5% opacity
  static const Color glassSurface   = Color(0x1A0D1526);   // Dark glass

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)],
  );

  static const RadialGradient orbIdleGradient = RadialGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0077AA), Color(0xFF00203A)],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient orbListeningGradient = RadialGradient(
    colors: [Color(0xFF00FF88), Color(0xFF007744), Color(0xFF001A0E)],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient orbProcessingGradient = RadialGradient(
    colors: [Color(0xFFA855F7), Color(0xFF6D28D9), Color(0xFF1A0033)],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient orbGreetingGradient = RadialGradient(
    colors: [Color(0xFFFFD700), Color(0xFFB8860B), Color(0xFF2D1E00)],
    stops: [0.0, 0.5, 1.0],
  );

  static const RadialGradient orbErrorGradient = RadialGradient(
    colors: [Color(0xFFEF4444), Color(0xFF991B1B), Color(0xFF1A0000)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Returns the correct orb gradient for the given avatar state name.
  static RadialGradient orbGradientFor(String state) {
    switch (state) {
      case 'listening': return orbListeningGradient;
      case 'processing': return orbProcessingGradient;
      case 'greeting': return orbGreetingGradient;
      case 'error': return orbErrorGradient;
      default: return orbIdleGradient;
    }
  }

  /// Returns the neon glow color for the given avatar state name.
  static Color glowColorFor(String state) {
    switch (state) {
      case 'listening': return greenAccent;
      case 'processing': return purpleAccent;
      case 'greeting': return goldAccent;
      case 'error': return redError;
      default: return cyanPrimary;
    }
  }
}
