import 'package:chronosense/domain/model/models.dart';

/// Bidirectional mapping between DB maps and domain models.
class EntityMapper {
  const EntityMapper._();

  static JournalEntry fromMap(Map<String, dynamic> map) {
    // Parse tags
    final tagsStr = map['tags'] as String? ?? '';
    final tags = tagsStr.isEmpty
        ? <ActivityTag>[]
        : tagsStr
            .split(',')
            .map((t) => ActivityTag.fromLabel(t.trim()))
            .where((t) => t != null)
            .cast<ActivityTag>()
            .toList();

    // Parse moods (comma-separated)
    final moodStr = map['mood'] as String? ?? '';
    final moods = moodStr.isEmpty
        ? <Mood>[]
        : moodStr
            .split(',')
            .map((m) => Mood.fromName(m.trim()))
            .where((m) => m != null)
            .cast<Mood>()
            .toList();

    return JournalEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      description: map['description'] as String? ?? '',
      moods: moods,
      tags: tags,
      createdAt: map['createdAt'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> toMap(JournalEntry entry) {
    final dateStr =
        '${entry.date.year.toString().padLeft(4, '0')}-'
        '${entry.date.month.toString().padLeft(2, '0')}-'
        '${entry.date.day.toString().padLeft(2, '0')}';

    return {
      if (entry.id != null) 'id': entry.id,
      'date': dateStr,
      'startTime': entry.startTime,
      'endTime': entry.endTime,
      'description': entry.description,
      'mood': entry.moods.map((m) => m.name).join(','),
      'tags': entry.tags.map((t) => t.label).join(','),
      'createdAt': entry.createdAt,
    };
  }
}
