import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chronosense/data/local/app_database.dart';

/// Data Access Object for journal_entries table.
class JournalDao {
  JournalDao._();
  static final JournalDao instance = JournalDao._();

  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Map<String, dynamic>>> getEntriesForDate(String date) async {
    if (kIsWeb) {
      final key = _webKey(date);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return [];
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
      } catch (e, st) {
        print('JournalDao.getEntriesForDate: web decode error for date=$date -> $e');
        print(st);
        return [];
      }
    }
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
    if (kIsWeb) {
      // Collect all dates between startDate and endDate inclusive
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final prefs = await SharedPreferences.getInstance();
      final results = <Map<String, dynamic>>[];
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final key = _webKey(_formatDate(d));
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          results.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      results.sort((a, b) {
        final da = a['date'] as String;
        final dbv = b['date'] as String;
        final comp = da.compareTo(dbv);
        if (comp != 0) return comp;
        return (a['startTime'] as String).compareTo(b['startTime'] as String);
      });
      return results;
    }
    final db = await _db;
    return db.query(
      'journal_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, startTime ASC',
    );
  }

  Future<Map<String, dynamic>?> getEntryById(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      // Search all keys
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('journal_entries:')) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          for (final item in list) {
            final map = Map<String, dynamic>.from(item as Map);
            if (map['id'] == id) return map;
          }
        } catch (_) {}
      }
      return null;
    }
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
    if (kIsWeb) {
      final key = _webKey(date);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['startTime'] == startTime) return map;
        }
      } catch (e, st) {
        print('JournalDao.getEntryBySlot: web decode error for date=$date start=$startTime -> $e');
        print(st);
      }
      return null;
    }
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
    if (kIsWeb) {
      final key = _webKey(entry['date'] as String);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final list = <Map<String, dynamic>>[];
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          list.addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
        } catch (e, st) {
          print('JournalDao.upsertEntry: web decode error for key=$key -> $e');
          print(st);
        }
      }

      // Try to find existing by startTime
      final idx = list.indexWhere((m) => m['startTime'] == entry['startTime']);
      if (idx != -1) {
        // preserve id if present
        entry['id'] = list[idx]['id'] ?? entry['id'];
        list[idx] = Map<String, dynamic>.from(entry);
      } else {
        // assign id if missing
        entry['id'] = entry['id'] ?? DateTime.now().millisecondsSinceEpoch;
        list.add(Map<String, dynamic>.from(entry));
      }

      await prefs.setString(key, jsonEncode(list));
      return entry['id'] as int;
    }
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('journal_entries:')) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final newList = list.where((m) => m['id'] != id).toList();
          if (newList.length != list.length) {
            await prefs.setString(key, jsonEncode(newList));
          }
        } catch (_) {}
      }
      return;
    }
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
    if (kIsWeb) {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final prefs = await SharedPreferences.getInstance();
      var cnt = 0;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final key = _webKey(_formatDate(d));
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          for (final item in list) {
            final m = Map<String, dynamic>.from(item as Map);
            final has = (m['description'] as String?)?.isNotEmpty == true ||
                (m['mood'] as String?)?.isNotEmpty == true ||
                (m['tags'] as String?)?.isNotEmpty == true;
            if (has) cnt++;
          }
        } catch (_) {}
      }
      return cnt;
    }
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM journal_entries '
      'WHERE date >= ? AND date <= ? AND (description != \'\' OR mood != \'\' OR tags != \'\')',
      [startDate, endDate],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  String _webKey(String date) => 'journal_entries:$date';

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
