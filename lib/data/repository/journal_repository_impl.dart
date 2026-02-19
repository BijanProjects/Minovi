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
    print('JournalRepositoryImpl.getEntriesForDate: date=$key');
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final rows = await _dao.getEntriesForDate(key);
    final entries = rows.map(EntityMapper.fromMap).toList();
    print('JournalRepositoryImpl.getEntriesForDate: loaded ${entries.length} entries from DAO');
    _cache.put(key, entries);
    return entries;
  }

  Future<List<JournalEntry>> getEntriesForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    print('JournalRepositoryImpl.getEntriesForDateRange: start=${_dateKey(start)} end=${_dateKey(end)}');
    final rows = await _dao.getEntriesForDateRange(
      _dateKey(start),
      _dateKey(end),
    );
    print('JournalRepositoryImpl.getEntriesForDateRange: loaded ${rows.length} rows from DAO');
    return rows.map(EntityMapper.fromMap).toList();
  }

  Future<JournalEntry?> getEntryById(int id) async {
    print('JournalRepositoryImpl.getEntryById: id=$id');
    final row = await _dao.getEntryById(id);
    return row != null ? EntityMapper.fromMap(row) : null;
  }

  Future<JournalEntry?> getEntryBySlot(
    DateTime date,
    String startTime,
  ) async {
    print('JournalRepositoryImpl.getEntryBySlot: date=${_dateKey(date)} startTime=$startTime');
    final row = await _dao.getEntryBySlot(_dateKey(date), startTime);
    print('JournalRepositoryImpl.getEntryBySlot: row=${row != null}');
    return row != null ? EntityMapper.fromMap(row) : null;
  }

  Future<int> upsertEntry(JournalEntry entry) async {
    print('JournalRepositoryImpl.upsertEntry: entry date=${_dateKey(entry.date)} start=${entry.startTime} id=${entry.id}');
    final map = EntityMapper.toMap(entry);
    final id = await _dao.upsertEntry(map);
    print('JournalRepositoryImpl.upsertEntry: dao returned id=$id');
    _cache.invalidate(_dateKey(entry.date));
    return id;
  }

  Future<void> deleteEntry(int id, DateTime date) async {
    print('JournalRepositoryImpl.deleteEntry: id=$id date=${_dateKey(date)}');
    await _dao.deleteEntry(id);
    _cache.invalidate(_dateKey(date));
  }

  Future<int> getEntryCountForRange(DateTime start, DateTime end) async {
    return _dao.getEntryCountForRange(_dateKey(start), _dateKey(end));
  }
}
