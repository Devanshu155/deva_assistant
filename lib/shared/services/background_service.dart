import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Speech To Text in the background isolate
  final SpeechToText stt = SpeechToText();
  bool isReady = await stt.initialize(
    onError: (e) => debugPrint('[Ambient] STT Error: ${e.errorMsg}'),
    onStatus: (status) {
      debugPrint('[Ambient] STT Status: $status');
      // If it stops listening, we want to restart it immediately to keep it "Always On"
      if (status == 'done' || status == 'notListening') {
        _startAmbientListening(stt, service);
      }
    },
  );

  service.on('stopService').listen((event) {
    stt.stop();
    service.stopSelf();
  });

  if (isReady) {
    _startAmbientListening(stt, service);
  }
}

void _startAmbientListening(SpeechToText stt, ServiceInstance service) async {
  if (stt.isListening) return;

  // We use the device's default locale
  final systemLocale = await stt.systemLocale();
  final localeId = systemLocale?.localeId ?? 'en_US';

  await stt.listen(
    onResult: (SpeechRecognitionResult result) {
      final transcript = result.recognizedWords.toLowerCase();
      
      // Wake Word Trigger Logic
      if (transcript.contains('hey deva') || transcript.contains('deva wake up')) {
        debugPrint('[Ambient] WAKE WORD DETECTED!');
        
        // Stop listening temporarily so the main app can take over the mic
        stt.stop();

        // Fire an event back to the main UI thread
        service.invoke('wakeWordDetected', {'transcript': transcript});
      }
    },
    listenFor: const Duration(seconds: 60), // Listen for long stretches
    pauseFor: const Duration(seconds: 3),
    partialResults: true, // Need partials to catch the wake word mid-sentence
    localeId: localeId,
    cancelOnError: true,
    listenMode: ListenMode.dictation,
  );
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Don't auto-start on boot unless user explicitly allows
      isForegroundMode: true,
      foregroundServiceTypes: ['microphone'],
      notificationChannelId: 'deva_ambient',
      initialNotificationTitle: 'DEVA Ambient Mode',
      initialNotificationContent: 'Listening for "Hey DEVA"...',
      initialNotificationIcon: 'ic_launcher',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: (ServiceInstance service) {
        return false;
      },
    ),
  );
}
