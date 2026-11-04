/// Assistant Riverpod provider — orchestrates the full DEVA lifecycle.
/// Greeting → Speaking → Listening → Processing → Speaking → Listening (loop)
/// Phase 2.3: Also manages the floating overlay when app is in background.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../data/models/assistant_state.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/action_service.dart';
import '../../../../shared/services/voice_service.dart';
import '../../../../shared/services/overlay_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/database/history_dao.dart';
import '../../../../shared/database/preferences_dao.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/deva_logger.dart';

final assistantProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>(
  (ref) => AssistantNotifier(),
);

class AssistantNotifier extends StateNotifier<AssistantState> {
  final VoiceService _voice;
  final AiService _ai;
  final ActionService _action;
  final HistoryDao _history;
  final OverlayService _overlay;
  final NotificationService _notifications;
  final PreferencesDao _prefs;

  AssistantNotifier({
    VoiceService? voice,
    AiService? ai,
    ActionService? action,
    HistoryDao? history,
    OverlayService? overlay,
    NotificationService? notifications,
    PreferencesDao? preferences,
  })  : _voice = voice ?? VoiceService.instance,
        _ai = ai ?? AiService.instance,
        _action = action ?? ActionService.instance,
        _history = history ?? HistoryDao.instance,
        _overlay = overlay ?? OverlayService.instance,
        _notifications = notifications ?? NotificationService.instance,
        _prefs = preferences ?? PreferencesDao.instance,
        super(const AssistantState()) {
    _init();
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<Map<String, dynamic>?>? _wakeWordSub;
  StreamSubscription? _overlayMsgSub;
  StreamSubscription? _notificationSub;

  bool _isAppInForeground = true;

  // ── Initialization ────────────────────────────────────────────────────

  /// Initializes all subsystems with module-level error isolation.
  ///
  /// If any individual subsystem (voice, overlay, notifications) fails to
  /// initialize, the failure is logged and the app continues in a degraded
  /// state rather than crashing. This is critical for production resilience:
  /// a missing microphone permission should not prevent the user from
  /// browsing settings or using text-based features.
  Future<void> _init() async {
    // 1. Initialize voice engine (may fail if mic permission denied)
    bool voiceReady = false;
    try {
      voiceReady = await _voice.initialize();
      if (!voiceReady) {
        DevaLogger.warn('AssistantNotifier', 'Voice engine returned false — mic may be unavailable');
      }
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Voice init failed — degraded mode', e, st);
    }

    // 2. Wire voice callbacks (safe even if init failed — callbacks just won't fire)
    _voice.onPartialResult = (partial) {
      if (mounted && state.status == DevaState.listening) {
        state = state.copyWith(partialTranscript: partial);
      }
      _pushStatusToOverlay();
    };
    _voice.onFinalResult = _onFinalSpeechResult;
    _voice.onTtsComplete = _onTtsComplete;
    _voice.onError = _handleError;

    // 3. Monitor connectivity
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
            _onConnectivityChanged,
          );
      final connectivity = await Connectivity().checkConnectivity();
      final offline = !connectivity.contains(ConnectivityResult.mobile) &&
          !connectivity.contains(ConnectivityResult.wifi) &&
          !connectivity.contains(ConnectivityResult.ethernet);
      state = state.copyWith(isOffline: offline);
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Connectivity check failed', e, st);
    }

    // 4. Subscribe to wake word events from background service
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _wakeWordSub = FlutterBackgroundService()
            .on('wakeWordDetected')
            .listen((event) async {
          if (!mounted) return;
          if (_isAppInForeground) {
            if (state.status == DevaState.idle) {
              await _startListening();
            }
          } else {
            await _showOverlayAndListen();
          }
        });
      }
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Wake word subscription failed', e, st);
    }

    // 5. Subscribe to messages FROM the overlay widget
    try {
      _overlayMsgSub = _overlay.overlayMessages.listen((data) async {
        if (data is Map) {
          final action = data['action'] as String?;
          if (action == 'open_app' || action == 'openApp') {
            await _overlay.hideOverlay();
            await _action.execute('open_app', {
              'app_name': AppConstants.appName,
              'package_name': AppConstants.packageName,
            });
          }
        }
      });
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Overlay subscription failed', e, st);
    }

    // 6. Check and cache overlay permission status
    try {
      await _overlay.checkPermission();
    } catch (e) {
      DevaLogger.warn('AssistantNotifier', 'Overlay permission check failed: $e');
    }

    // 7. Initialize Notification Listener
    try {
      _notifications.initialize();
      _notificationSub =
          _notifications.notifications.listen(_handleIncomingNotification);
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Notification listener init failed', e, st);
    }

    // 8. Start with greeting on launch
    if (voiceReady) {
      await _greet();
    } else {
      // Voice unavailable — set error state so the user knows.
      DevaLogger.warn('AssistantNotifier', 'Skipping greeting — voice engine not ready');
      if (mounted) {
        state = state.copyWith(
          status: DevaState.error,
          errorMessage: 'Voice service unavailable. Check microphone permissions.',
        );
        // Auto-recover to idle after a brief error display.
        await Future.delayed(const Duration(milliseconds: AppConstants.avatarErrorMs));
        if (mounted) {
          state = state.copyWith(status: DevaState.idle, clearError: true);
        }
      }
    }
  }

  // ── Notifications (Phase 4.5) ──────────────────────────────────────────

  Future<void> _handleIncomingNotification(Map<String, dynamic> data) async {
    if (!mounted) return;

    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final pkg = data['package'] as String? ?? '';

    // Only interrupt if DEVA is currently idle. If talking/listening, ignore to avoid chaos.
    if (state.status == DevaState.idle) {
      String appName = 'an app';
      if (pkg.contains('whatsapp')) {
        appName = 'WhatsApp';
      } else if (pkg.contains('gmail')) {
        appName = 'Gmail';
      } else if (pkg.contains('message')) {
        appName = 'Messages';
      }

      final announcement =
          "You just received a message on $appName from $title. It says: $text";

      DevaLogger.ui('Notification received from $appName: $title');

      // Wake up and speak the notification
      state = state.copyWith(status: DevaState.speaking);
      _pushStatusToOverlay();
      try {
        await _voice.speak(announcement);
      } catch (e) {
        DevaLogger.error('AssistantNotifier', 'Failed to speak notification', e);
        if (mounted) {
          state = state.copyWith(status: DevaState.idle, clearError: true);
        }
      }
    }
  }

  // ── Overlay (Phase 2.3) ────────────────────────────────────────────────

  /// Show floating overlay and start listening — used when wake word fires
  /// while the main app is in the background.
  Future<void> _showOverlayAndListen() async {
    final overlayOpened = await _overlay.showOverlay();
    if (!overlayOpened) {
      debugPrint(
          '[Assistant] Overlay failed to open; continuing with voice listen in background.');
    }

    state = state.copyWith(
      status: DevaState.listening,
      partialTranscript: '',
      clearError: true,
    );
    await _voice.startListening();
    _pushStatusToOverlay();
  }

  /// Push the current DevaState to the floating overlay so its UI stays in sync.
  void _pushStatusToOverlay() {
    _overlay.sendToOverlay({'status': state.status.label});
  }

  // ── Greeting (auto-start on app open) ────────────────────────────────

  Future<void> _greet() async {
    try {
      if (!mounted) return;
      state = state.copyWith(status: DevaState.greeting, clearError: true);
      await Future.delayed(
          const Duration(milliseconds: AppConstants.avatarGreetingMs));
      if (!mounted) return;
      state = state.copyWith(status: DevaState.speaking);

      if (state.isOffline) {
        await _voice.speak(AppConstants.offlineMessage);
      } else {
        await _voice.speak(AppConstants.greetingMessage);
      }
      // _onTtsComplete fires and triggers auto-listen
    } catch (e, st) {
      DevaLogger.error('AssistantNotifier', 'Greeting failed', e, st);
      if (mounted) {
        state = state.copyWith(status: DevaState.idle, clearError: true);
      }
    }
  }

  // ── TTS complete → auto-listen ────────────────────────────────────────

  Future<void> _onTtsComplete() async {
    if (!mounted) {
      return;
    }
    if (state.status == DevaState.speaking ||
        state.status == DevaState.success) {
      if (state.isOffline) {
        state = state.copyWith(status: DevaState.idle);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _startListening();
    }
  }

  // ── Listening ─────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!mounted || state.isOffline) {
      return;
    }
    state = state.copyWith(
      status: DevaState.listening,
      partialTranscript: '',
      clearError: true,
    );
    await _voice.startListening();
    _pushStatusToOverlay();
  }

  Future<void> onAvatarTapped() async {
    if (state.isOffline) {
      final haptic = await _prefs.getHapticFeedback();
      if (haptic) {
        await HapticFeedback.mediumImpact();
      }
      state = state.copyWith(status: DevaState.speaking);
      _pushStatusToOverlay();
      await _voice.speak(AppConstants.offlineMessage);
      return;
    }

    if (state.status == DevaState.idle) {
      await _startListening();
    } else if (state.status == DevaState.listening) {
      await _voice.stopListening();
      state = state.copyWith(status: DevaState.idle);
    } else if (state.status == DevaState.speaking) {
      await _voice.stopSpeaking();
      await _startListening();
    }
  }

  // ── Speech recognized ─────────────────────────────────────────────────

  Future<void> _onFinalSpeechResult(String text) async {
    if (!mounted || text.isEmpty) {
      return;
    }

    if (text == '__barge_in_triggered__') {
      await _startListening();
      return;
    }

    state = state.copyWith(
      status: DevaState.processing,
      lastUserText: text,
      partialTranscript: '',
    );
    _pushStatusToOverlay();

    final stopwatch = Stopwatch()..start();

    // Send to AI
    final aiResponse = await _ai.sendCommand(text);
    stopwatch.stop();

    if (!mounted) {
      return;
    }

    // Execute any tool calls
    String spokenText = aiResponse.text;
    if (aiResponse.hasToolCall) {
      final actionResult = await _action.execute(
          aiResponse.toolName!, aiResponse.toolArgs ?? {});

      if (!actionResult.success && actionResult.message != null) {
        // Action failed — speak the error
        spokenText = actionResult.message!;
      } else if (actionResult.success) {
        // Action succeeded — show success state briefly
        state = state.copyWith(status: DevaState.success);
        _pushStatusToOverlay();

        // Use action's message if AI didn't provide spoken text
        if (aiResponse.text.isEmpty || aiResponse.text == 'Done!') {
          spokenText = actionResult.message ?? 'Done, sir.';
        }
      }
    }

    // Store in local history
    await _history.insert(
      userText: text,
      aiResponse: spokenText,
      toolUsed: aiResponse.toolName,
      toolArgs: aiResponse.toolArgs?.toString(),
      durationMs: stopwatch.elapsedMilliseconds,
    );

    // Speak with the detected language (multi-language support)
    state = state.copyWith(
      status: DevaState.speaking,
      lastAiResponse: spokenText,
    );
    _pushStatusToOverlay();
    await _voice.speak(spokenText, langCode: aiResponse.detectedLangCode);

    // If we were running in overlay mode, hide after speaking
    if (!_isAppInForeground && await _overlay.isActive) {
      await Future.delayed(const Duration(seconds: 1));
      await _overlay.hideOverlay();
    }
    // _onTtsComplete auto-loops back to listening
  }

  // ── Error handling ────────────────────────────────────────────────────

  Future<void> _handleError(String message) async {
    if (!mounted) return;

    DevaLogger.warn('AssistantNotifier', 'Voice error: $message');

    // Ignore timeout or no-speech errors and gracefully return to idle state
    if (message == 'error_speech_timeout' || message == 'error_no_match') {
      state = state.copyWith(status: DevaState.idle);
      _pushStatusToOverlay();
      return;
    }

    state = state.copyWith(status: DevaState.error, errorMessage: message);
    _pushStatusToOverlay();
    await Future.delayed(
      const Duration(milliseconds: AppConstants.avatarErrorMs),
    );
    if (!mounted) return;
    state = state.copyWith(status: DevaState.idle, clearError: true);
    _pushStatusToOverlay();
  }

  // ── Connectivity ──────────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = !results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);
    state = state.copyWith(isOffline: offline);

    if (offline && state.status == DevaState.listening) {
      _voice.stopListening();
      state = state.copyWith(status: DevaState.speaking);
      _voice.speak(AppConstants.offlineMessage);
    }
  }

  // ── App lifecycle ─────────────────────────────────────────────────────

  /// Call from AssistantScreen when the app goes to background (paused).
  Future<void> pause() async {
    _isAppInForeground = false;
    await _voice.stopListening();
    await _voice.stopSpeaking();
    state = state.copyWith(status: DevaState.idle);
  }

  /// Call from AssistantScreen when the app returns to foreground (resumed).
  Future<void> resume() async {
    _isAppInForeground = true;
    // If the overlay is open and user brought the app forward, close the overlay
    if (await _overlay.isActive) {
      await _overlay.hideOverlay();
    }
    if (state.status == DevaState.idle && !state.isOffline) {
      await _startListening();
    }
  }

  // ── Overlay permission helper (called from Settings screen) ───────────

  Future<bool> requestOverlayPermission() => _overlay.requestPermission();

  Future<bool> hasOverlayPermission() => _overlay.checkPermission();

  // ── Cleanup ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _wakeWordSub?.cancel();
    _overlayMsgSub?.cancel();
    _notificationSub?.cancel();
    _notifications.dispose();
    _voice.dispose();
    super.dispose();
  }
}
