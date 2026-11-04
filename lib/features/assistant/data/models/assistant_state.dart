/// Assistant state model — defines every possible state of DEVA.
library;

import 'package:flutter/foundation.dart';

/// All visual/behavioral states of the DEVA avatar.
enum DevaState {
  greeting, // Initial boot-up greeting ("Hello sir")
  idle, // Calm breathing — long silence or awaiting re-engage
  listening, // Microphone active, waiting for speech
  processing, // Waiting for AI response
  speaking, // TTS playing AI response
  success, // Brief success animation after action
  error, // Something went wrong
}

extension DevaStateX on DevaState {
  String get label {
    switch (this) {
      case DevaState.greeting:
        return 'GREETING';
      case DevaState.idle:
        return 'STANDBY';
      case DevaState.listening:
        return 'LISTENING';
      case DevaState.processing:
        return 'THINKING';
      case DevaState.speaking:
        return 'SPEAKING';
      case DevaState.success:
        return 'DONE';
      case DevaState.error:
        return 'ERROR';
    }
  }

  /// Maps state to a color identifier used by AppColors.glowColorFor().
  String get colorKey {
    switch (this) {
      case DevaState.greeting:
        return 'greeting';
      case DevaState.idle:
        return 'idle';
      case DevaState.listening:
        return 'listening';
      case DevaState.processing:
        return 'processing';
      case DevaState.speaking:
        return 'idle'; // cyan, same as idle
      case DevaState.success:
        return 'listening'; // green
      case DevaState.error:
        return 'error';
    }
  }

  bool get isActive => this != DevaState.idle;
}

/// Immutable state for the assistant feature.
@immutable
class AssistantState {
  final DevaState status;
  final String partialTranscript; // Live speech-to-text result (before final)
  final String lastUserText; // Final recognized command
  final String lastAiResponse; // AI spoken response
  final String? errorMessage;
  final bool isOffline;

  const AssistantState({
    this.status = DevaState.idle,
    this.partialTranscript = '',
    this.lastUserText = '',
    this.lastAiResponse = '',
    this.errorMessage,
    this.isOffline = false,
  });

  AssistantState copyWith({
    DevaState? status,
    String? partialTranscript,
    String? lastUserText,
    String? lastAiResponse,
    String? errorMessage,
    bool? isOffline,
    bool clearError = false,
  }) =>
      AssistantState(
        status: status ?? this.status,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        lastUserText: lastUserText ?? this.lastUserText,
        lastAiResponse: lastAiResponse ?? this.lastAiResponse,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        isOffline: isOffline ?? this.isOffline,
      );

  @override
  String toString() => 'AssistantState(status: $status, offline: $isOffline, '
      'partial: "$partialTranscript", last: "$lastUserText")';
}
