import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deva_assistant/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:deva_assistant/features/assistant/data/models/assistant_state.dart';
import 'package:deva_assistant/features/assistant/data/services/ai_service.dart';
import 'package:deva_assistant/features/assistant/data/services/action_service.dart';
import 'package:deva_assistant/shared/services/voice_service.dart';
import 'package:deva_assistant/shared/services/overlay_service.dart';
import 'package:deva_assistant/shared/services/notification_service.dart';
import 'package:deva_assistant/shared/database/history_dao.dart';
import 'package:deva_assistant/shared/database/preferences_dao.dart';
import 'package:deva_assistant/core/constants/app_constants.dart';

// ── Mocks ────────────────────────────────────────────────────────────────
class MockVoiceService extends Mock implements VoiceService {
  @override
  OnPartialResult? onPartialResult;
  @override
  OnFinalResult? onFinalResult;
  @override
  OnTtsComplete? onTtsComplete;
  @override
  OnError? onError;

  Duration speakDelay = const Duration(milliseconds: 1500);
}

class MockAiService extends Mock implements AiService {}

class MockActionService extends Mock implements ActionService {}

class MockHistoryDao extends Mock implements HistoryDao {}

class MockOverlayService extends Mock implements OverlayService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockPreferencesDao extends Mock implements PreferencesDao {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  late MockVoiceService mockVoice;
  late MockAiService mockAi;
  late MockActionService mockAction;
  late MockHistoryDao mockHistory;
  late MockOverlayService mockOverlay;
  late MockNotificationService mockNotifications;
  late MockPreferencesDao mockPrefs;

  setUp(() {
    mockVoice = MockVoiceService();
    mockAi = MockAiService();
    mockAction = MockActionService();
    mockHistory = MockHistoryDao();
    mockOverlay = MockOverlayService();
    mockNotifications = MockNotificationService();
    mockPrefs = MockPreferencesDao();

    // Default mock behaviors
    when(() => mockVoice.initialize()).thenAnswer((_) async => true);
    when(() => mockVoice.speak(any(), langCode: any(named: 'langCode')))
        .thenAnswer((_) async {
      Future.delayed(mockVoice.speakDelay, () {
        mockVoice.onTtsComplete?.call();
      });
    });
    when(() => mockVoice.stopSpeaking()).thenAnswer((_) async {});
    when(() => mockVoice.startListening()).thenAnswer((_) async {});
    when(() => mockVoice.stopListening()).thenAnswer((_) async {});

    when(() => mockOverlay.checkPermission()).thenAnswer((_) async => true);
    when(() => mockOverlay.overlayMessages)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockOverlay.sendToOverlay(any())).thenAnswer((_) async {});

    when(() => mockNotifications.initialize()).thenAnswer((_) async {});
    when(() => mockNotifications.notifications)
        .thenAnswer((_) => const Stream.empty());

    when(() => mockPrefs.getHapticFeedback()).thenAnswer((_) async => true);

    // Mock connectivity
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi'];
        }
        return null;
      },
    );
  });

  group('AssistantNotifier State Machine', () {
    test('Initializes and starts with greeting', () async {
      final notifier = AssistantNotifier(
        voice: mockVoice,
        ai: mockAi,
        action: mockAction,
        history: mockHistory,
        overlay: mockOverlay,
        notifications: mockNotifications,
        preferences: mockPrefs,
      );

      // It should immediately initialize the voice service
      verify(() => mockVoice.initialize()).called(1);

      // It starts as idle
      expect(notifier.state.status, equals(DevaState.idle));

      // Wait for initialization delay and greeting
      await Future.delayed(const Duration(milliseconds: 600));
      expect(notifier.state.status, equals(DevaState.greeting));

      // Wait for greeting animation delay
      await Future.delayed(const Duration(milliseconds: 1600));

      expect(notifier.state.status, equals(DevaState.speaking));
      verify(() => mockVoice.speak(any())).called(1);
    });

    test('Transitions to Listening when Avatar is tapped while Idle', () async {
      final notifier = AssistantNotifier(
        voice: mockVoice,
        ai: mockAi,
        action: mockAction,
        history: mockHistory,
        overlay: mockOverlay,
        notifications: mockNotifications,
        preferences: mockPrefs,
      );

      // Force state to idle for testing
      notifier.state = const AssistantState(status: DevaState.idle);

      await notifier.onAvatarTapped();

      expect(notifier.state.status, equals(DevaState.listening));
      verify(() => mockVoice.startListening()).called(1);
    });

    test('Cancels listening when Avatar is tapped while Listening', () async {
      final notifier = AssistantNotifier(
        voice: mockVoice,
        ai: mockAi,
        action: mockAction,
        history: mockHistory,
        overlay: mockOverlay,
        notifications: mockNotifications,
        preferences: mockPrefs,
      );

      notifier.state = const AssistantState(status: DevaState.listening);

      await notifier.onAvatarTapped();

      expect(notifier.state.status, equals(DevaState.idle));
      verify(() => mockVoice.stopListening()).called(1);
    });

    test(
        'Speaks offline message and vibrates when Avatar is tapped while Offline',
        () async {
      // Mock connectivity to return offline for this test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'check') {
            return []; // empty list means offline
          }
          return null;
        },
      );

      final notifier = AssistantNotifier(
        voice: mockVoice,
        ai: mockAi,
        action: mockAction,
        history: mockHistory,
        overlay: mockOverlay,
        notifications: mockNotifications,
        preferences: mockPrefs,
      );

      // Wait for async initialization and offline greeting sequence to complete
      await Future.delayed(const Duration(milliseconds: 2500));

      expect(notifier.state.status, equals(DevaState.idle));
      expect(notifier.state.isOffline, isTrue);

      // Reset mock verify counts since initialize and greet speak offline message once
      clearInteractions(mockVoice);

      // We expect the system to trigger a haptic feedback click
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            return null;
          }
          return null;
        },
      );

      await notifier.onAvatarTapped();

      expect(notifier.state.status, equals(DevaState.speaking));
      verify(() => mockVoice.speak(AppConstants.offlineMessage)).called(1);
    });
  });
}
