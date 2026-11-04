/// History DAO — all command history stored locally via SQLite.
library;

import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../core/constants/app_constants.dart';

/// A single history entry representing one voice command + AI response.
class HistoryEntry {
  final String id;
  final String userText;
  final String aiResponse;
  final String? toolUsed;
  final String? toolArgs;
  final DateTime createdAt;
  final int? durationMs;

  const HistoryEntry({
    required this.id,
    required this.userText,
    required this.aiResponse,
    this.toolUsed,
    this.toolArgs,
    required this.createdAt,
    this.durationMs,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] as String,
        userText: map['user_text'] as String,
        aiResponse: map['ai_response'] as String,
        toolUsed: map['tool_used'] as String?,
        toolArgs: map['tool_args'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        durationMs: map['duration_ms'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_text': userText,
        'ai_response': aiResponse,
        'tool_used': toolUsed,
        'tool_args': toolArgs,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration_ms': durationMs,
      };
}

/// Data access object for the history table.
class HistoryDao {
  HistoryDao._();
  static final HistoryDao instance = HistoryDao._();

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  /// Insert a new history entry. Returns the generated ID.
  Future<String> insert({
    required String userText,
    required String aiResponse,
    String? toolUsed,
    String? toolArgs,
    int? durationMs,
  }) async {
    final db = await _db.database;
    final entry = HistoryEntry(
      id: _uuid.v4(),
      userText: userText,
      aiResponse: aiResponse,
      toolUsed: toolUsed,
      toolArgs: toolArgs,
      createdAt: DateTime.now(),
      durationMs: durationMs,
    );
    await db.insert(AppConstants.tableHistory, entry.toMap());
    return entry.id;
  }

  /// Retrieve all history entries, newest first.
  Future<List<HistoryEntry>> getAll({int limit = 100}) async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.tableHistory,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  /// Delete a single entry by ID.
  Future<void> deleteById(String id) async {
    final db = await _db.database;
    await db.delete(
      AppConstants.tableHistory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all history.
  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete(AppConstants.tableHistory);
  }

  /// Total count of stored commands.
  Future<int> count() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AppConstants.tableHistory}',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
