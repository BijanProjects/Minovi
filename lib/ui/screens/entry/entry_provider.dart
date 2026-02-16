import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class EntryUiState {
  final bool isLoading;
  final JournalEntry? existingEntry;
  final String description;
  final Mood? mood;
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
    this.mood,
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
    Mood? mood,
    bool clearMood = false,
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
      mood: clearMood ? null : (mood ?? this.mood),
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
class EntryNotifier extends StateNotifier<EntryUiState> {
  final Ref ref;

  EntryNotifier(this.ref) : super(const EntryUiState());

  Future<void> loadEntry({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
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
      state = state.copyWith(
        isLoading: false,
        existingEntry: existing,
        description: existing.description,
        mood: existing.mood,
        clearMood: existing.mood == null,
        tags: existing.tags,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        clearExisting: true,
        description: '',
        clearMood: true,
        tags: [],
      );
    }
  }

  void updateDescription(String value) {
    if (value.length <= 5000) {
      state = state.copyWith(description: value);
    }
  }

  void updateMood(Mood? mood) {
    if (mood == null) {
      state = state.copyWith(clearMood: true);
    } else {
      state = state.copyWith(mood: mood);
    }
  }

  void updateTags(List<ActivityTag> tags) {
    state = state.copyWith(tags: tags);
  }

  Future<void> save() async {
    final repo = ref.read(journalRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final parsedDate = DateTime.parse(state.date);

    final entry = JournalEntry(
      id: state.existingEntry?.id,
      date: parsedDate,
      startTime: state.startTime,
      endTime: state.endTime,
      description: state.description.trim(),
      mood: state.mood,
      tags: state.tags,
      createdAt: state.existingEntry?.createdAt ?? now,
    );

    await repo.upsertEntry(entry);
    state = state.copyWith(isSaved: true);
  }

  Future<void> delete() async {
    final existing = state.existingEntry;
    if (existing?.id != null) {
      final repo = ref.read(journalRepositoryProvider);
      await repo.deleteEntry(existing!.id!, existing.date);
      state = state.copyWith(isDeleted: true);
    }
  }
}

final entryProvider = StateNotifierProvider.autoDispose<EntryNotifier, EntryUiState>(
  (ref) => EntryNotifier(ref),
);
