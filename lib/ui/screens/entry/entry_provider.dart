import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/di/refresh_signal.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class EntryUiState {
  final bool isLoading;
  final JournalEntry? existingEntry;
  final String description;
  final List<String> moods;
  final List<String> tags;
  final List<String> moodCategories;
  final List<String> actionCategories;
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
    this.moodCategories = const [],
    this.actionCategories = const [],
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
    List<String>? moods,
    List<String>? tags,
    List<String>? moodCategories,
    List<String>? actionCategories,
    String? date,
    String? startTime,
    String? endTime,
    bool? isSaved,
    bool? isDeleted,
  }) {
    return EntryUiState(
      isLoading: isLoading ?? this.isLoading,
      existingEntry:
          clearExisting ? null : (existingEntry ?? this.existingEntry),
      description: description ?? this.description,
      moods: moods ?? this.moods,
      tags: tags ?? this.tags,
      moodCategories: moodCategories ?? this.moodCategories,
      actionCategories: actionCategories ?? this.actionCategories,
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
  static const _moodCategoriesKey = 'entry_mood_categories';
  static const _actionCategoriesKey = 'entry_action_categories';
  static const _maxMoodSelections = 3;

  @override
  EntryUiState build() => const EntryUiState();

  Future<void> _loadCategoryOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultMoods = Mood.values.map((m) => m.label).toList();
    final defaultActions = ActivityTag.values.map((t) => t.label).toList();
    final moodCategories = prefs.getStringList(_moodCategoriesKey);
    final actionCategories = prefs.getStringList(_actionCategoriesKey);

    final normalizedMoodCategories =
        (moodCategories == null || moodCategories.isEmpty)
            ? defaultMoods
            : moodCategories
                .map(normalizeMoodLabel)
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList();
    final normalizedActionCategories =
        (actionCategories == null || actionCategories.isEmpty)
            ? defaultActions
            : actionCategories
                .map(normalizeActivityLabel)
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList();

    state = state.copyWith(
      moodCategories: normalizedMoodCategories,
      actionCategories: normalizedActionCategories,
    );
  }

  Future<void> _saveCategoryOptions({
    List<String>? moodCategories,
    List<String>? actionCategories,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (moodCategories != null) {
      await prefs.setStringList(_moodCategoriesKey, moodCategories);
    }
    if (actionCategories != null) {
      await prefs.setStringList(_actionCategoriesKey, actionCategories);
    }
  }

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
    await _loadCategoryOptions();

    final repo = ref.read(journalRepositoryProvider);
    final parsedDate = DateTime.parse(date);
    final existing = await repo.getEntryBySlot(parsedDate, startTime);

    if (existing != null) {
      print('EntryNotifier.loadEntry: found existing entry id=${existing.id}');
      final moodCategories = {
        ...state.moodCategories,
        ...existing.moods.map(normalizeMoodLabel),
      }.where((e) => e.isNotEmpty).toList();
      final actionCategories = {
        ...state.actionCategories,
        ...existing.tags.map(normalizeActivityLabel),
      }.where((e) => e.isNotEmpty).toList();
      await _saveCategoryOptions(
        moodCategories: moodCategories,
        actionCategories: actionCategories,
      );

      state = state.copyWith(
        isLoading: false,
        existingEntry: existing,
        description: existing.description,
        moods: existing.moods,
        tags: existing.tags,
        moodCategories: moodCategories,
        actionCategories: actionCategories,
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

  void updateMoods(List<String> moods) {
    print('EntryNotifier.updateMoods: moods=$moods');
    state = state.copyWith(moods: moods);
  }

  void updateTags(List<String> tags) {
    print('EntryNotifier.updateTags: tags=$tags');
    state = state.copyWith(tags: tags);
  }

  void toggleMoodSelection(String mood) {
    final normalized = normalizeMoodLabel(mood);
    if (normalized.isEmpty) return;
    final current = List<String>.from(state.moods);
    if (current.contains(normalized)) {
      current.remove(normalized);
    } else {
      if (current.length >= _maxMoodSelections) return;
      current.add(normalized);
    }
    updateMoods(current);
  }

  void toggleTagSelection(String tag) {
    final normalized = normalizeActivityLabel(tag);
    if (normalized.isEmpty) return;
    final current = List<String>.from(state.tags);
    if (current.contains(normalized)) {
      current.remove(normalized);
    } else {
      current.add(normalized);
    }
    updateTags(current);
  }

  Future<void> addMoodCategory(String mood) async {
    final normalized = normalizeMoodLabel(mood);
    if (normalized.isEmpty) return;
    final categories = List<String>.from(state.moodCategories);
    if (categories.contains(normalized)) return;
    categories.add(normalized);
    state = state.copyWith(moodCategories: categories);
    await _saveCategoryOptions(moodCategories: categories);
  }

  Future<void> addActionCategory(String action) async {
    final normalized = normalizeActivityLabel(action);
    if (normalized.isEmpty) return;
    final categories = List<String>.from(state.actionCategories);
    if (categories.contains(normalized)) return;
    categories.add(normalized);
    state = state.copyWith(actionCategories: categories);
    await _saveCategoryOptions(actionCategories: categories);
  }

  Future<void> removeMoodCategory(String mood) async {
    final categories = List<String>.from(state.moodCategories)
      ..removeWhere((m) => m.toLowerCase() == mood.toLowerCase());
    final selected = List<String>.from(state.moods)
      ..removeWhere((m) => m.toLowerCase() == mood.toLowerCase());
    state = state.copyWith(moodCategories: categories, moods: selected);
    await _saveCategoryOptions(moodCategories: categories);
  }

  Future<void> removeActionCategory(String action) async {
    final categories = List<String>.from(state.actionCategories)
      ..removeWhere((t) => t.toLowerCase() == action.toLowerCase());
    final selected = List<String>.from(state.tags)
      ..removeWhere((t) => t.toLowerCase() == action.toLowerCase());
    state = state.copyWith(actionCategories: categories, tags: selected);
    await _saveCategoryOptions(actionCategories: categories);
  }

  Future<void> save() async {
    print(
        'EntryNotifier.save: saving entry for date=${state.date} start=${state.startTime} end=${state.endTime}');
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
      final entry = existing!;
      print('EntryNotifier.delete: deleting id=${entry.id} date=${entry.date}');
      final repo = ref.read(journalRepositoryProvider);
      await repo.deleteEntry(entry.id!, entry.date);
      ref.read(refreshSignalProvider.notifier).notify();
      state = state.copyWith(isDeleted: true);
    }
  }
}

final entryProvider = NotifierProvider.autoDispose<EntryNotifier, EntryUiState>(
  EntryNotifier.new,
);
