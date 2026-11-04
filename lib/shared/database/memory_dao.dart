/// Memory DAO — key/value store for things the user asks DEVA to remember.
/// All memory stays on-device. Never sent anywhere.
library;

import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../core/constants/app_constants.dart';

class MemoryEntry {
  final String id;
  final String keyName;
  final String value;
  final String category; // 'preference' | 'fact' | 'task' | 'contact'
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryEntry({
    required this.id,
    required this.keyName,
    required this.value,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryEntry.fromMap(Map<String, dynamic> map) => MemoryEntry(
        id: map['id'] as String,
        keyName: map['key_name'] as String,
        value: map['value'] as String,
        category: map['category'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'key_name': keyName,
        'value': value,
        'category': category,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };
}

class MemoryDao {
  MemoryDao._();
  static final MemoryDao instance = MemoryDao._();

  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  /// Upsert a memory (insert or update if key already exists).
  Future<void> upsert({
    required String key,
    required String value,
    String category = 'fact',
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      AppConstants.tableMemory,
      where: 'key_name = ?',
      whereArgs: [key],
    );

    if (existing.isEmpty) {
      await db.insert(AppConstants.tableMemory, {
        'id': _uuid.v4(),
        'key_name': key,
        'value': value,
        'category': category,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        AppConstants.tableMemory,
        {'value': value, 'category': category, 'updated_at': now},
        where: 'key_name = ?',
        whereArgs: [key],
      );
    }
  }

  /// Get all memory entries.
  Future<List<MemoryEntry>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.tableMemory,
      orderBy: 'updated_at DESC',
    );
    return rows.map(MemoryEntry.fromMap).toList();
  }

  /// Get a specific memory value by key.
  Future<String?> getValue(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      AppConstants.tableMemory,
      columns: ['value'],
      where: 'key_name = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Build a context string from all memory — injected into the AI prompt.
  Future<String> buildContextString() async {
    final entries = await getAll();
    if (entries.isEmpty) return '';
    final buffer = StringBuffer('User memory context:\n');
    for (final e in entries) {
      buffer.writeln('- ${e.keyName}: ${e.value}');
    }
    return buffer.toString();
  }

  Future<void> deleteByKey(String key) async {
    final db = await _db.database;
    await db.delete(
      AppConstants.tableMemory,
      where: 'key_name = ?',
      whereArgs: [key],
    );
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete(AppConstants.tableMemory);
  }
}
