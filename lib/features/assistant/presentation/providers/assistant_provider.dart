/// Assistant Riverpod provider — orchestrates the full DEVA lifecycle.
/// Greeting → Speaking → Listening → Processing → Speaking → Listening (loop)
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/assistant_state.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/action_service.dart';
import '../../../../shared/services/voice_service.dart';
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

  final _voice  = VoiceService.instance;
  final _ai     = AiService.instance;
  final _action = ActionService.instance;
  final _history = HistoryDao.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> _init() async {
    // 1. Initialize voice engine
    await _voice.initialize();

    // 2. Wire voice callbacks
    _voice.onPartialResult = (partial) {
      if (state.status == DevaState.listening) {
        state = state.copyWith(partialTranscript: partial);
      }
    };
    _voice.onFinalResult = _onFinalSpeechResult;
    _voice.onTtsComplete = _onTtsComplete;
    _voice.onError = (err) => _handleError(err);

    // 3. Monitor connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    final connectivity = await Connectivity().checkConnectivity();
    final offline = !connectivity.contains(ConnectivityResult.mobile) &&
                    !connectivity.contains(ConnectivityResult.wifi) &&
                    !connectivity.contains(ConnectivityResult.ethernet);
    state = state.copyWith(isOffline: offline);

    // 4. Start with greeting on launch
    await _greet();
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
    // _onTtsComplete will fire and trigger auto-listen
  }

  // ── TTS complete → auto-listen ────────────────────────────────────────

  Future<void> _onTtsComplete() async {
    if (!mounted) return;
    // After speaking, automatically start listening again (conversation loop)
    if (state.status == DevaState.speaking ||
        state.status == DevaState.success) {
      if (state.isOffline) {
        // Offline: stay idle, don't listen for AI commands
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
      status: DevaState.listening,
      partialTranscript: '',
      clearError: true,
    );
    await _voice.startListening();
  }

  /// Called by the avatar tap — re-engage from idle.
  Future<void> onAvatarTapped() async {
    if (state.status == DevaState.idle) {
      await _startListening();
    } else if (state.status == DevaState.listening) {
      // Double-tap to cancel
      await _voice.stopListening();
      state = state.copyWith(status: DevaState.idle);
    }
  }

  // ── Speech recognized ─────────────────────────────────────────────────

  Future<void> _onFinalSpeechResult(String text) async {
    if (!mounted || text.isEmpty) return;

    state = state.copyWith(
      status: DevaState.processing,
      lastUserText: text,
      partialTranscript: '',
    );

    final stopwatch = Stopwatch()..start();

    // Send to AI
    final aiResponse = await _ai.sendCommand(text);
    stopwatch.stop();

    if (!mounted) return;

    // Execute any tool calls
    if (aiResponse.hasToolCall) {
      await _action.execute(
        aiResponse.toolName!,
        aiResponse.toolArgs ?? {},
      );
    }

    // Store in local history
    await _history.insert(
      userText:    text,
      aiResponse:  aiResponse.text,
      toolUsed:    aiResponse.toolName,
      toolArgs:    aiResponse.toolArgs?.toString(),
      durationMs:  stopwatch.elapsedMilliseconds,
    );

    // Speak the response
    state = state.copyWith(
      status: DevaState.speaking,
      lastAiResponse: aiResponse.text,
    );
    await _voice.speak(aiResponse.text);
    // _onTtsComplete auto-loops back to listening
  }

  // ── Error handling ────────────────────────────────────────────────────

  Future<void> _handleError(String message) async {
    if (!mounted) return;
    state = state.copyWith(
      status: DevaState.error,
      errorMessage: message,
    );
    await Future.delayed(
      const Duration(milliseconds: AppConstants.avatarErrorMs),
    );
    if (!mounted) return;
    // Retry listening after error
    await _startListening();
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

  // ── Public controls ───────────────────────────────────────────────────

  /// Stop everything and go idle (e.g., navigated away from main screen).
  Future<void> pause() async {
    await _voice.stopListening();
    await _voice.stopSpeaking();
    state = state.copyWith(status: DevaState.idle);
  }

  /// Resume after coming back to the assistant screen.
  Future<void> resume() async {
    if (state.status == DevaState.idle && !state.isOffline) {
      await _startListening();
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _voice.dispose();
    super.dispose();
  }
}
