import 'package:chronosense/domain/model/models.dart';

/// Thread-safe LRU cache for day entries (max 14 days).
class DayCache {
  final int _maxSize;
  final Map<String, List<JournalEntry>> _cache = {};
  final List<String> _accessOrder = [];

  DayCache({int maxSize = 14}) : _maxSize = maxSize;

  List<JournalEntry>? get(String dateKey) {
    if (_cache.containsKey(dateKey)) {
      _accessOrder.remove(dateKey);
      _accessOrder.add(dateKey);
      return _cache[dateKey];
    }
    return null;
  }

  void put(String dateKey, List<JournalEntry> entries) {
    if (_cache.containsKey(dateKey)) {
      _accessOrder.remove(dateKey);
    } else if (_cache.length >= _maxSize) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[dateKey] = entries;
    _accessOrder.add(dateKey);
  }

  void invalidate(String dateKey) {
    _cache.remove(dateKey);
    _accessOrder.remove(dateKey);
  }

  void invalidateAll() {
    _cache.clear();
    _accessOrder.clear();
  }
}
