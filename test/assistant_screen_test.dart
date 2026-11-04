import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:deva_assistant/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:deva_assistant/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:deva_assistant/features/assistant/data/models/assistant_state.dart';

// Create a mock notifier
class MockAssistantNotifier extends StateNotifier<AssistantState>
    implements AssistantNotifier {
  MockAssistantNotifier() : super(const AssistantState());

  @override
  Future<void> onAvatarTapped() async {
    if (state.status == DevaState.idle) {
      state = state.copyWith(status: DevaState.listening);
    } else if (state.status == DevaState.listening) {
      state = state.copyWith(status: DevaState.idle);
    }
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> hasOverlayPermission() async => true;
}

void main() {
  Widget createWidgetUnderTest(MockAssistantNotifier mockNotifier) {
    return ProviderScope(
      overrides: [
        assistantProvider.overrideWith((ref) => mockNotifier),
      ],
      child: const MaterialApp(
        home: AssistantScreen(),
      ),
    );
  }

  group('AssistantScreen Widget Tests', () {
    testWidgets('Displays IDLE state correctly', (WidgetTester tester) async {
      final mockNotifier = MockAssistantNotifier();
      mockNotifier.state = const AssistantState(status: DevaState.idle);

      await tester.pumpWidget(createWidgetUnderTest(mockNotifier));

      // Verify label
      expect(find.text('STANDBY'), findsOneWidget);
    });

    testWidgets('Displays LISTENING state and transcript',
        (WidgetTester tester) async {
      final mockNotifier = MockAssistantNotifier();
      mockNotifier.state = const AssistantState(
        status: DevaState.listening,
        partialTranscript: 'turn on the',
      );

      await tester.pumpWidget(createWidgetUnderTest(mockNotifier));

      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.text('turn on the'), findsOneWidget);
    });

    testWidgets('Displays PROCESSING state', (WidgetTester tester) async {
      final mockNotifier = MockAssistantNotifier();
      mockNotifier.state = const AssistantState(status: DevaState.processing);

      await tester.pumpWidget(createWidgetUnderTest(mockNotifier));

      expect(find.text('THINKING'), findsOneWidget);
    });

    testWidgets('Tapping Avatar changes state from IDLE to LISTENING',
        (WidgetTester tester) async {
      final mockNotifier = MockAssistantNotifier();
      mockNotifier.state = const AssistantState(status: DevaState.idle);

      await tester.pumpWidget(createWidgetUnderTest(mockNotifier));
      expect(find.text('STANDBY'), findsOneWidget);

      // Find the DevaAvatar (using a GestureDetector or its exact type)
      // The avatar is wrapped in a GestureDetector inside DevaAvatar
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('LISTENING'), findsOneWidget);
    });
  });
}
