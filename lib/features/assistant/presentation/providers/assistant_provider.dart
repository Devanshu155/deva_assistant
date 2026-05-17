/// Assistant Riverpod provider — orchestrates the full DEVA lifecycle.
/// Greeting → Speaking → Listening → Processing → Speaking → Listening (loop)
/// Phase 2.3: Also manages the floating overlay when app is in background.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../data/models/assistant_state.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/action_service.dart';
import '../../../../shared/services/voice_service.dart';
import '../../../../shared/services/overlay_service.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/database/history_dao.dart';
import '../../../../core/constants/app_constants.dart';

final assistantProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>(
  (ref) => AssistantNotifier(),
);

class AssistantNotifier extends StateNotifier<AssistantState> {
  AssistantNotifier() : super(const AssistantState()) {
    _init();
  }

  final _voice   = VoiceService.instance;
  final _ai      = AiService.instance;
  final _action  = ActionService.instance;
  final _history = HistoryDao.instance;
  final _overlay = OverlayService.instance;
  final _notifications = NotificationService.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<Map<String, dynamic>?>?    _wakeWordSub;
  StreamSubscription?                           _overlayMsgSub;
  StreamSubscription?                           _notificationSub;

  bool _isAppInForeground = true;

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> _init() async {
    // 1. Initialize voice engine
    await _voice.initialize();

    // 2. Wire voice callbacks
    _voice.onPartialResult = (partial) {
      if (state.status == DevaState.listening) {
        state = state.copyWith(partialTranscript: partial);
      }
      // Also push partial result to overlay if visible
      _pushStatusToOverlay();
    };
    _voice.onFinalResult = _onFinalSpeechResult;
    _voice.onTtsComplete = _onTtsComplete;
    _voice.onError       = _handleError;

    // 3. Monitor connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    final connectivity = await Connectivity().checkConnectivity();
    final offline = !connectivity.contains(ConnectivityResult.mobile) &&
                    !connectivity.contains(ConnectivityResult.wifi)   &&
                    !connectivity.contains(ConnectivityResult.ethernet);
    state = state.copyWith(isOffline: offline);

    // 4. Subscribe to wake word events from background service
    _wakeWordSub = FlutterBackgroundService()
        .on('wakeWordDetected')
        .listen((event) async {
      if (!mounted) return;
      if (_isAppInForeground) {
        // App is open — just start listening in the main UI
        if (state.status == DevaState.idle) await _startListening();
      } else {
        // App is in background — show the floating overlay
        await _showOverlayAndListen();
      }
    });

    // 5. Subscribe to messages FROM the overlay widget
    _overlayMsgSub = _overlay.overlayMessages.listen((data) async {
      if (data is Map) {
        if (data['action'] == 'open_app') {
          // User tapped overlay → hide it and bring main app to front
          await _overlay.hideOverlay();
        }
      }
    });

    // 6. Check and cache overlay permission status
    await _overlay.checkPermission();

    // 7. Initialize Notification Listener
    _notifications.initialize();
    _notificationSub = _notifications.notifications.listen(_handleIncomingNotification);

    // 8. Start with greeting on launch
    await _greet();
  }

  // ── Notifications (Phase 4.5) ──────────────────────────────────────────

  void _handleIncomingNotification(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final pkg = data['package'] as String? ?? '';
    
    // Only interrupt if DEVA is currently idle. If talking/listening, ignore to avoid chaos.
    if (state.status == DevaState.idle) {
       String appName = 'an app';
       if (pkg.contains('whatsapp')) appName = 'WhatsApp';
       else if (pkg.contains('gmail')) appName = 'Gmail';
       else if (pkg.contains('message')) appName = 'Messages';

       final announcement = "You just received a message on $appName from $title. It says: $text";
       
       // Wake up and speak the notification
       state = state.copyWith(status: DevaState.speaking);
       _pushStatusToOverlay();
       await _voice.speak(announcement);
    }
  }

  // ── Overlay (Phase 2.3) ────────────────────────────────────────────────

  /// Show floating overlay and start listening — used when wake word fires
  /// while the main app is in the background.
  Future<void> _showOverlayAndListen() async {
    await _overlay.showOverlay();
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
    state = state.copyWith(status: DevaState.greeting, clearError: true);
    await Future.delayed(const Duration(milliseconds: AppConstants.avatarGreetingMs));
    state = state.copyWith(status: DevaState.speaking);

    if (state.isOffline) {
      await _voice.speak(AppConstants.offlineMessage);
    } else {
      await _voice.speak(AppConstants.greetingMessage);
    }
    // _onTtsComplete fires and triggers auto-listen
  }

  // ── TTS complete → auto-listen ────────────────────────────────────────

  Future<void> _onTtsComplete() async {
    if (!mounted) return;
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
    if (!mounted || state.isOffline) return;
    state = state.copyWith(
      status:            DevaState.listening,
      partialTranscript: '',
      clearError:        true,
    );
    await _voice.startListening();
    _pushStatusToOverlay();
  }

  /// Called by the avatar tap — re-engage from idle.
  Future<void> onAvatarTapped() async {
    if (state.status == DevaState.idle) {
      await _startListening();
    } else if (state.status == DevaState.listening) {
      await _voice.stopListening();
      state = state.copyWith(status: DevaState.idle);
    }
  }

  // ── Speech recognized ─────────────────────────────────────────────────

  Future<void> _onFinalSpeechResult(String text) async {
    if (!mounted || text.isEmpty) return;

    state = state.copyWith(
      status:            DevaState.processing,
      lastUserText:      text,
      partialTranscript: '',
    );
    _pushStatusToOverlay();

    final stopwatch = Stopwatch()..start();

    // Send to AI
    final aiResponse = await _ai.sendCommand(text);
    stopwatch.stop();

    if (!mounted) return;

    // Execute any tool calls
    String spokenText = aiResponse.text;
    if (aiResponse.hasToolCall) {
      final actionResult = await _action.execute(aiResponse.toolName!, aiResponse.toolArgs ?? {});
      // If the action failed and provided a message, speak the error message instead
      if (!actionResult.success && actionResult.message != null) {
        spokenText = actionResult.message!;
      } else if (aiResponse.text == 'Done!' && actionResult.message != null) {
        // If AI had no spoken text but the action returned a success message, use it
        spokenText = actionResult.message!;
      }
    }

    // Store in local history
    await _history.insert(
      userText:   text,
      aiResponse: spokenText,
      toolUsed:   aiResponse.toolName,
      toolArgs:   aiResponse.toolArgs?.toString(),
      durationMs: stopwatch.elapsedMilliseconds,
    );

    // Speak with the detected language (multi-language support)
    state = state.copyWith(
      status:         DevaState.speaking,
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
    state = state.copyWith(status: DevaState.idle);
    _pushStatusToOverlay();
  }

  // ── Connectivity ──────────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = !results.contains(ConnectivityResult.mobile) &&
                    !results.contains(ConnectivityResult.wifi)   &&
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
    if (await _overlay.isActive) await _overlay.hideOverlay();
    if (state.status == DevaState.idle && !state.isOffline) {
      await _startListening();
    }
  }

  // ── Overlay permission helper (called from Settings screen) ───────────

  Future<bool> requestOverlayPermission() =>
      _overlay.requestPermission();

  Future<bool> hasOverlayPermission() =>
      _overlay.checkPermission();

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
