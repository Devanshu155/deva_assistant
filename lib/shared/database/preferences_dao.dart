/// Preferences DAO — local SQLite-backed user settings.
library;

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/database_helper.dart';
import '../../core/constants/app_constants.dart';

class PreferencesDao {
  PreferencesDao._();
  static final PreferencesDao instance = PreferencesDao._();

  final _db = DatabaseHelper.instance;

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.tablePreferences,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      AppConstants.tablePreferences,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Voice settings ────────────────────────────────────────────────────

  Future<double> getSpeechRate() async {
    final v = await _get('speech_rate');
    return double.tryParse(v ?? '') ?? AppConstants.defaultSpeechRate;
  }

  Future<void> setSpeechRate(double rate) async => _set('speech_rate', '$rate');

  Future<double> getTtsPitch() async {
    final v = await _get('tts_pitch');
    return double.tryParse(v ?? '') ?? AppConstants.defaultTtsPitch;
  }

  Future<void> setTtsPitch(double pitch) async => _set('tts_pitch', '$pitch');

  Future<double> getTtsVolume() async {
    final v = await _get('tts_volume');
    return double.tryParse(v ?? '') ?? AppConstants.defaultTtsVolume;
  }

  Future<void> setTtsVolume(double volume) async =>
      _set('tts_volume', '$volume');

  // ── Haptic feedback ───────────────────────────────────────────────────

  Future<bool> getHapticFeedback() async {
    final v = await _get('haptic_feedback');
    return v != 'false'; // default true
  }

  Future<void> setHapticFeedback(bool enabled) async =>
      _set('haptic_feedback', '$enabled');

  // ── Display name ──────────────────────────────────────────────────────

  Future<String> getDisplayName() async {
    final v = await _get('display_name');
    return v ?? 'Sir';
  }

  Future<void> setDisplayName(String name) async => _set('display_name', name);

  // ── Voice language ─────────────────────────────────────────────────────

  /// Get the preferred voice language locale ID for STT (e.g., 'hi_IN', 'en_US').
  /// Returns null if not set, meaning "auto-detect from device".
  Future<String?> getVoiceLanguage() async => _get('voice_language');

  /// Set the preferred voice language locale ID for STT.
  Future<void> setVoiceLanguage(String localeId) async =>
      _set('voice_language', localeId);

  Future<void> customSet(String key, String value) async => _set(key, value);
  Future<String?> customGet(String key) async => _get(key);

  // ── All as map ────────────────────────────────────────────────────────

  Future<Map<String, String>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(AppConstants.tablePreferences);
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }
}
