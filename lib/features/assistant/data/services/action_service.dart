/// Action service — executes tool calls returned by the AI.
/// Routes each tool to the appropriate platform bridge or system service.
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/database/memory_dao.dart';

class ActionResult {
  final bool success;
  final String? message; // Optional feedback for TTS

  const ActionResult({required this.success, this.message});
}

class ActionService {
  ActionService._();
  static final ActionService instance = ActionService._();

  static const _appLauncherChannel =
      MethodChannel(AppConstants.channelAppLauncher);
  static const _systemActionChannel =
      MethodChannel(AppConstants.channelSystemAction);

  final _memory = MemoryDao.instance;

  // ── Main dispatch ─────────────────────────────────────────────────────

  /// Execute a tool call from the AI. Returns a result with optional feedback.
  Future<ActionResult> execute(
      String toolName, Map<String, dynamic> args) async {
    debugPrint('[Action] Executing tool: $toolName, args: $args');

    switch (toolName) {
      case 'open_app':    return _openApp(args);
      case 'web_search':  return _webSearch(args);
      case 'set_reminder':return _setReminder(args);
      case 'remember':    return _remember(args);
      case 'open_url':    return _openUrl(args);
      default:
        return ActionResult(
          success: false,
          message: 'I don\'t know how to do "$toolName" yet.',
        );
    }
  }

  // ── Tool implementations ──────────────────────────────────────────────

  /// Open an app via Kotlin native bridge.
  Future<ActionResult> _openApp(Map<String, dynamic> args) async {
    try {
      final appName     = args['app_name'] as String? ?? '';
      final packageName = args['package_name'] as String?;

      final result = await _appLauncherChannel.invokeMethod<String>(
        'openApp',
        {'app_name': appName, 'package_name': packageName},
      );

      return ActionResult(success: true, message: result);
    } on PlatformException catch (e) {
      debugPrint('[Action] openApp error: ${e.message}');
      return ActionResult(
        success: false,
        message: 'I couldn\'t open that app. ${e.message}',
      );
    }
  }

  /// Open browser with a web search query.
  Future<ActionResult> _webSearch(Map<String, dynamic> args) async {
    final query = Uri.encodeComponent(args['query'] as String? ?? '');
    final uri = Uri.parse('https://www.google.com/search?q=$query');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const ActionResult(success: true);
      }
      return const ActionResult(success: false, message: 'I couldn\'t open the browser.');
    } catch (e) {
      return ActionResult(success: false, message: 'Search failed: $e');
    }
  }

  /// Open a specific URL.
  Future<ActionResult> _openUrl(Map<String, dynamic> args) async {
    final rawUrl = args['url'] as String? ?? '';
    // Security: only allow https URLs
    if (!rawUrl.startsWith('https://')) {
      return const ActionResult(
        success: false,
        message: 'I can only open secure HTTPS links.',
      );
    }
    try {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const ActionResult(success: true);
      }
      return const ActionResult(success: false, message: 'I couldn\'t open that link.');
    } catch (e) {
      return ActionResult(success: false, message: 'Failed to open URL: $e');
    }
  }

  /// Set a reminder/alarm via Kotlin native bridge.
  Future<ActionResult> _setReminder(Map<String, dynamic> args) async {
    try {
      await _systemActionChannel.invokeMethod('setAlarm', {
        'title':     args['title'] as String? ?? 'Reminder',
        'time':      args['time'] as String? ?? '',
        'recurring': args['recurring'] as bool? ?? false,
      });
      return const ActionResult(success: true);
    } on PlatformException catch (e) {
      return ActionResult(success: false, message: 'Could not set reminder: ${e.message}');
    }
  }

  /// Store a memory entry locally in SQLite.
  Future<ActionResult> _remember(Map<String, dynamic> args) async {
    final key      = args['key']      as String? ?? '';
    final value    = args['value']    as String? ?? '';
    final category = args['category'] as String? ?? 'fact';

    if (key.isEmpty || value.isEmpty) {
      return const ActionResult(success: false, message: 'I need a key and value to remember something.');
    }

    await _memory.upsert(key: key, value: value, category: category);
    return ActionResult(
      success: true,
      message: 'I\'ve remembered that "$key" is "$value".',
    );
  }
}
