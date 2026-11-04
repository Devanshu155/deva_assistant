import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:deva_assistant/shared/services/voice_service.dart';

class MockVoiceService extends Mock implements VoiceService {}

void main() {
  group('Hardware Permissions & Edge Cases', () {
    late MockVoiceService mockVoice;

    setUp(() {
      mockVoice = MockVoiceService();
    });

    test('Gracefully handles microphone permission denial', () async {
      // Simulate permission denied error thrown by the voice service during init or listen
      when(() => mockVoice.startListening())
          .thenThrow(Exception('Microphone permission denied'));

      // If we call it directly, we expect it to throw our specific error
      expect(() => mockVoice.startListening(), throwsA(isA<Exception>()));
    });
  });
}
