import 'package:chronosense/data/local/journal_dao.dart';
import 'package:chronosense/data/mapper/entity_mapper.dart';
import 'package:chronosense/data/cache/day_cache.dart';
import 'package:chronosense/domain/model/models.dart';

/// Repository implementation backed by SQLite + LRU cache.
class JournalRepositoryImpl {
  final JournalDao _dao;
  final DayCache _cache;

  JournalRepositoryImpl({
    JournalDao? dao,
    DayCache? cache,
  })  : _dao = dao ?? JournalDao.instance,
        _cache = cache ?? DayCache();

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<List<JournalEntry>> getEntriesForDate(DateTime date) async {
    final key = _dateKey(date);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final rows = await _dao.getEntriesForDate(key);
    final entries = rows.map(EntityMapper.fromMap).toList();
    _cache.put(key, entries);
    return entries;
  }

  Future<List<JournalEntry>> getEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _dao.getEntriesForDateRange(
      _dateKey(start),
      _dateKey(end),
    );
    return rows.map(EntityMapper.fromMap).toList();
  }

  Future<JournalEntry?> getEntryById(int id) async {
    final row = await _dao.getEntryById(id);
    return row != null ? EntityMapper.fromMap(row) : null;
  }

  Future<JournalEntry?> getEntryBySlot(
    DateTime date,
    String startTime,
  ) async {
    final row = await _dao.getEntryBySlot(_dateKey(date), startTime);
    return row != null ? EntityMapper.fromMap(row) : null;
  }

  Future<int> upsertEntry(JournalEntry entry) async {
    final map = EntityMapper.toMap(entry);
    final id = await _dao.upsertEntry(map);
    _cache.invalidate(_dateKey(entry.date));
    return id;
  }

  Future<void> deleteEntry(int id, DateTime date) async {
    await _dao.deleteEntry(id);
    _cache.invalidate(_dateKey(date));
  }

  Future<int> getEntryCountForRange(DateTime start, DateTime end) async {
    return _dao.getEntryCountForRange(_dateKey(start), _dateKey(end));
  }
}
