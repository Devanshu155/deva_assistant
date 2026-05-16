/// SQLite local database helper — ALL user data lives on device.
/// No data is ever sent to a server. Privacy is non-negotiable.
library;

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import '../services/secure_storage_service.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  // ── Init ──────────────────────────────────────────────────────────────
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    final key = await SecureStorageService.instance.getDbEncryptionKey();

    return openDatabase(
      path,
      password: key,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Command history — stored locally, never leaves device
    await db.execute('''
      CREATE TABLE ${AppConstants.tableHistory} (
        id          TEXT PRIMARY KEY,
        user_text   TEXT NOT NULL,
        ai_response TEXT NOT NULL,
        tool_used   TEXT,
        tool_args   TEXT,
        created_at  INTEGER NOT NULL,
        duration_ms INTEGER
      )
    ''');

    // Memory — key/value pairs the user asks DEVA to remember
    await db.execute('''
      CREATE TABLE ${AppConstants.tableMemory} (
        id          TEXT PRIMARY KEY,
        key_name    TEXT NOT NULL UNIQUE,
        value       TEXT NOT NULL,
        category    TEXT NOT NULL DEFAULT 'fact',
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');

    // Preferences — voice settings, theme, etc.
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePreferences} (
        key         TEXT PRIMARY KEY,
        value       TEXT NOT NULL
      )
    ''');

    // Seed default preferences
    await db.insert(AppConstants.tablePreferences,
        {'key': 'speech_rate', 'value': '${AppConstants.defaultSpeechRate}'});
    await db.insert(AppConstants.tablePreferences,
        {'key': 'tts_pitch', 'value': '${AppConstants.defaultTtsPitch}'});
    await db.insert(AppConstants.tablePreferences,
        {'key': 'tts_volume', 'value': '${AppConstants.defaultTtsVolume}'});
    await db.insert(AppConstants.tablePreferences,
        {'key': 'haptic_feedback', 'value': 'true'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future-proof: handle migrations here as schema evolves
  }

  // ── Utility ───────────────────────────────────────────────────────────

  /// Permanently delete all local data — used in Settings > Clear All Data.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.tableHistory);
    await db.delete(AppConstants.tableMemory);
    // Preserve preferences (user settings survive data clear)
  }

  /// Close the database connection cleanly.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
