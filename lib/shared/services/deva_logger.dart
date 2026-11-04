/// Centralized, levelled logging service for DEVA.
///
/// All logs are printed to the debug console via [debugPrint] (which maps to
/// logcat in release builds). No logs are persisted to disk or transmitted.
///
/// Usage:
///   DevaLogger.permission('Accessibility granted');
///   DevaLogger.mcp('Foreground app: com.whatsapp');
///   DevaLogger.error('ActionService', 'HTTP call failed', e, st);
library;

import 'package:flutter/foundation.dart';

enum _Level { debug, info, warn, error }

class DevaLogger {
  DevaLogger._();

  // ── Module-specific convenience methods ───────────────────────────────

  static void permission(String msg, {Object? error, StackTrace? stack}) =>
      _log('PERMISSION', _Level.info, msg, error, stack);

  static void accessibility(String msg, {Object? error, StackTrace? stack}) =>
      _log('ACCESSIBILITY', _Level.debug, msg, error, stack);

  static void mcp(String msg, {Object? error, StackTrace? stack}) =>
      _log('MCP', _Level.info, msg, error, stack);

  static void screenCapture(String msg, {Object? error, StackTrace? stack}) =>
      _log('SCREEN_CAPTURE', _Level.debug, msg, error, stack);

  static void playStore(String msg, {Object? error, StackTrace? stack}) =>
      _log('PLAY_STORE', _Level.info, msg, error, stack);

  static void voice(String msg, {Object? error, StackTrace? stack}) =>
      _log('VOICE', _Level.debug, msg, error, stack);

  static void ai(String msg, {Object? error, StackTrace? stack}) =>
      _log('AI', _Level.debug, msg, error, stack);

  static void ui(String msg, {Object? error, StackTrace? stack}) =>
      _log('UI', _Level.debug, msg, error, stack);

  /// Log a module-level error with a mandatory [error] object and optional
  /// [stack] trace so it can be inspected in logcat.
  static void error(
    String module,
    String msg,
    Object error, [
    StackTrace? stack,
  ]) =>
      _log(module.toUpperCase(), _Level.error, msg, error, stack);

  static void warn(String module, String msg, {Object? error}) =>
      _log(module.toUpperCase(), _Level.warn, msg, error, null);

  // ── Core printer ─────────────────────────────────────────────────────

  static void _log(
    String module,
    _Level level,
    String msg,
    Object? error,
    StackTrace? stack,
  ) {
    if (!kDebugMode && level == _Level.debug) return; // suppress debug in release

    final icon = switch (level) {
      _Level.debug => '🔵',
      _Level.info  => '🟢',
      _Level.warn  => '🟡',
      _Level.error => '🔴',
    };

    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:MM:SS.mmm
    final line = '$icon [$timestamp][$module] $msg';
    debugPrint(line);

    if (error != null) {
      debugPrint('   ↳ error: $error');
    }
    if (stack != null) {
      // Print only first 6 frames to keep logcat readable.
      final frames = stack
          .toString()
          .split('\n')
          .take(6)
          .map((f) => '     $f')
          .join('\n');
      debugPrint(frames);
    }
  }
}
