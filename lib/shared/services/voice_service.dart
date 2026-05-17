/// Voice service — wraps speech_to_text (STT) and flutter_tts (TTS).
/// All speech processing uses on-device engine (no cloud upload).
/// Supports dynamic multi-language: STT uses device locale, TTS auto-detects language.
library;

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';
import '../database/preferences_dao.dart';

/// Callback types for voice events.
typedef OnPartialResult = void Function(String partial);
typedef OnFinalResult   = void Function(String text);
typedef OnTtsComplete   = void Function();
typedef OnError         = void Function(String error);

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final SpeechToText _stt   = SpeechToText();
  final FlutterTts   _tts   = FlutterTts();
  final _prefs               = PreferencesDao.instance;

  bool   _sttReady   = false;
  bool   _isSpeaking = false;
  bool   _isListening = false;
  String _currentTtsLang = 'en-US'; // tracks the currently set TTS language

  // ── Callbacks ─────────────────────────────────────────────────────────
  OnPartialResult? onPartialResult;
  OnFinalResult?   onFinalResult;
  OnTtsComplete?   onTtsComplete;
  OnError?         onError;

  // ── Init ──────────────────────────────────────────────────────────────

  /// Initialise both engines. Call once at app startup.
  Future<bool> initialize() async {
    _sttReady = await _stt.initialize(
      onError: (e) => onError?.call(e.errorMsg),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );

    // Set initial TTS language from device locale
    _currentTtsLang = _deviceLocaleToTtsLang();
    await _applyTtsSettings();

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onTtsComplete?.call();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onError?.call('TTS error: $msg');
    });

    debugPrint('[VoiceService] Init complete. STT ready: $_sttReady, TTS lang: $_currentTtsLang');
    return _sttReady;
  }

  /// Converts Flutter device locale (e.g. "hi_IN") to a TTS BCP-47 language code (e.g. "hi-IN").
  String _deviceLocaleToTtsLang() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final lang   = locale.languageCode;
    final country = locale.countryCode ?? '';
    if (country.isNotEmpty) return '$lang-$country';
    // Common fallbacks
    const fallbacks = {
      'hi': 'hi-IN',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'es': 'es-ES',
      'zh': 'zh-CN',
      'ar': 'ar-SA',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'pt': 'pt-BR',
    };
    return fallbacks[lang] ?? 'en-US';
  }

  Future<void> _applyTtsSettings() async {
    final rate   = await _prefs.getSpeechRate();
    final pitch  = await _prefs.getTtsPitch();
    final volume = await _prefs.getTtsVolume();
    await _tts.setLanguage(_currentTtsLang);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
  }

  // ── TTS ───────────────────────────────────────────────────────────────

  /// Speak text aloud. Optionally pass a language code to switch TTS language.
  /// Used for multi-language: AI detects language, we switch TTS to match.
  Future<void> speak(String text, {String? langCode}) async {
    if (_isSpeaking) await _tts.stop();
    if (_isListening) await stopListening();

    // Dynamically switch TTS language if the AI responded in a different language
    if (langCode != null && langCode != _currentTtsLang) {
      _currentTtsLang = langCode;
      await _tts.setLanguage(langCode);
      debugPrint('[VoiceService] TTS language switched to: $langCode');
    }

    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Stop any ongoing speech.
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  // ── STT ───────────────────────────────────────────────────────────────

  /// Start listening for a voice command using device's current locale.
  Future<void> startListening() async {
    if (!_sttReady || _isListening || _isSpeaking) return;

    _isListening = true;

    // Multi-language: always use the device's current locale for STT
    final systemLocale = await _stt.systemLocale();
    final localeId     = systemLocale?.localeId ?? 'en_US';

    await _stt.listen(
      onResult:  _onSttResult,
      listenFor: const Duration(seconds: 30),
      pauseFor:  Duration(milliseconds: AppConstants.sttSilenceTimeout),
      localeId:  localeId,
      listenMode: ListenMode.confirmation,
    );
  }

  void _onSttResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _isListening = false;
      final text = result.recognizedWords.trim();
      if (text.isNotEmpty) onFinalResult?.call(text);
    } else {
      onPartialResult?.call(result.recognizedWords);
    }
  }

  /// Stop listening before the silence timeout.
  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
    }
  }

  // ── State getters ─────────────────────────────────────────────────────
  bool   get isSpeaking   => _isSpeaking;
  bool   get isListening  => _isListening;
  bool   get isReady      => _sttReady;
  String get ttsLanguage  => _currentTtsLang;

  // ── Settings reload (call after changing prefs in Settings screen) ─────
  Future<void> reloadSettings() async => _applyTtsSettings();

  // ── Cleanup ───────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await _tts.stop();
    await _stt.stop();
  }
}
