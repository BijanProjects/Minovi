import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/di/refresh_signal.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class EntryUiState {
  final bool isLoading;
  final JournalEntry? existingEntry;
  final String description;
  final List<Mood> moods;
  final List<ActivityTag> tags;
  final String date;
  final String startTime;
  final String endTime;
  final bool isSaved;
  final bool isDeleted;

  const EntryUiState({
    this.isLoading = true,
    this.existingEntry,
    this.description = '',
    this.moods = const [],
    this.tags = const [],
    this.date = '',
    this.startTime = '',
    this.endTime = '',
    this.isSaved = false,
    this.isDeleted = false,
  });

  EntryUiState copyWith({
    bool? isLoading,
    JournalEntry? existingEntry,
    bool clearExisting = false,
    String? description,
    List<Mood>? moods,
    List<ActivityTag>? tags,
    String? date,
    String? startTime,
    String? endTime,
    bool? isSaved,
    bool? isDeleted,
  }) {
    return EntryUiState(
      isLoading: isLoading ?? this.isLoading,
      existingEntry: clearExisting ? null : (existingEntry ?? this.existingEntry),
      description: description ?? this.description,
      moods: moods ?? this.moods,
      tags: tags ?? this.tags,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isSaved: isSaved ?? this.isSaved,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

// ── Notifier ──
class EntryNotifier extends Notifier<EntryUiState> {
  @override
  EntryUiState build() => const EntryUiState();

  Future<void> loadEntry({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    print('EntryNotifier.loadEntry: date=$date start=$startTime end=$endTime');
    state = state.copyWith(
      isLoading: true,
      date: date,
      startTime: startTime,
      endTime: endTime,
    );

    final repo = ref.read(journalRepositoryProvider);
    final parsedDate = DateTime.parse(date);
    final existing = await repo.getEntryBySlot(parsedDate, startTime);

    if (existing != null) {
      print('EntryNotifier.loadEntry: found existing entry id=${existing.id}');
      state = state.copyWith(
        isLoading: false,
        existingEntry: existing,
        description: existing.description,
        moods: existing.moods,
        tags: existing.tags,
      );
    } else {
      print('EntryNotifier.loadEntry: no existing entry found for slot');
      state = state.copyWith(
        isLoading: false,
        clearExisting: true,
        description: '',
        moods: [],
        tags: [],
      );
    }
  }

  void updateDescription(String value) {
    if (value.length <= 5000) {
      print('EntryNotifier.updateDescription: length=${value.length}');
      state = state.copyWith(description: value);
    }
  }

  void updateMoods(List<Mood> moods) {
    print('EntryNotifier.updateMoods: moods=${moods.map((m) => m.label).toList()}');
    state = state.copyWith(moods: moods);
  }

  void updateTags(List<ActivityTag> tags) {
    print('EntryNotifier.updateTags: tags=${tags.map((t) => t.label).toList()}');
    state = state.copyWith(tags: tags);
  }

  Future<void> save() async {
    print('EntryNotifier.save: saving entry for date=${state.date} start=${state.startTime} end=${state.endTime}');
    final repo = ref.read(journalRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final parsedDate = DateTime.parse(state.date);

    final entry = JournalEntry(
      id: state.existingEntry?.id,
      date: parsedDate,
      startTime: state.startTime,
      endTime: state.endTime,
      description: state.description.trim(),
      moods: state.moods,
      tags: state.tags,
      createdAt: state.existingEntry?.createdAt ?? now,
    );

    await repo.upsertEntry(entry);
    print('EntryNotifier.save: upsert requested (id=${entry.id})');
    ref.read(refreshSignalProvider.notifier).notify();
    state = state.copyWith(isSaved: true);
  }

  Future<void> delete() async {
    final existing = state.existingEntry;
    if (existing?.id != null) {
      print('EntryNotifier.delete: deleting id=${existing!.id} date=${existing.date}');
      final repo = ref.read(journalRepositoryProvider);
      await repo.deleteEntry(existing!.id!, existing.date);
      ref.read(refreshSignalProvider.notifier).notify();
      state = state.copyWith(isDeleted: true);
    }
  }
}
final entryProvider = NotifierProvider.autoDispose<EntryNotifier, EntryUiState>(
  EntryNotifier.new,
);
