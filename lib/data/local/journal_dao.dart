import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:chronosense/data/local/app_database.dart';

/// Data Access Object for journal_entries table.
class JournalDao {
  JournalDao._();
  static final JournalDao instance = JournalDao._();

  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Map<String, dynamic>>> getEntriesForDate(String date) async {
    if (kIsWeb) return [];
    final db = await _db;
    return db.query(
      'journal_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'startTime ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getEntriesForDateRange(
    String startDate,
    String endDate,
  ) async {
    if (kIsWeb) return [];
    final db = await _db;
    return db.query(
      'journal_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, startTime ASC',
    );
  }

  Future<Map<String, dynamic>?> getEntryById(int id) async {
    if (kIsWeb) return null;
    final db = await _db;
    final results = await db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getEntryBySlot(
    String date,
    String startTime,
  ) async {
    if (kIsWeb) return null;
    final db = await _db;
    final results = await db.query(
      'journal_entries',
      where: 'date = ? AND startTime = ?',
      whereArgs: [date, startTime],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> upsertEntry(Map<String, dynamic> entry) async {
    if (kIsWeb) return -1;
    final db = await _db;
    // Try to find existing entry for the same slot
    final existing = await getEntryBySlot(
      entry['date'] as String,
      entry['startTime'] as String,
    );
    if (existing != null && entry['id'] == null) {
      entry['id'] = existing['id'];
    }
    if (entry['id'] != null) {
      await db.update(
        'journal_entries',
        entry,
        where: 'id = ?',
        whereArgs: [entry['id']],
      );
      return entry['id'] as int;
    } else {
      return db.insert(
        'journal_entries',
        entry,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteEntry(int id) async {
    if (kIsWeb) return;
    final db = await _db;
    await db.delete(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getEntryCountForRange(
    String startDate,
    String endDate,
  ) async {
    if (kIsWeb) return 0;
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM journal_entries '
      'WHERE date >= ? AND date <= ? AND (description != \'\' OR mood != \'\' OR tags != \'\')',
      [startDate, endDate],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
