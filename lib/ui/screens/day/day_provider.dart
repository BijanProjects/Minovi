import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/algorithm/interval_engine.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/di/refresh_signal.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class DayUiState {
  final String formattedDate;
  final DateTime date;
  final List<TimeSlot> timeSlots;
  final double completionRate;
  final int filledCount;
  final int totalCount;
  final int activeSlotIndex;
  final bool isToday;
  final bool isLoading;
  final DayUiState? prevDay;
  final DayUiState? nextDay;

  DayUiState({
    this.formattedDate = '',
    DateTime? date,
    this.timeSlots = const [],
    this.completionRate = 0,
    this.filledCount = 0,
    this.totalCount = 0,
    this.activeSlotIndex = -1,
    this.isToday = true,
    this.isLoading = true,
    this.prevDay,
    this.nextDay,
  }) : date = date ?? DateTime.now();

  DayUiState copyWith({
    String? formattedDate,
    DateTime? date,
    List<TimeSlot>? timeSlots,
    double? completionRate,
    int? filledCount,
    int? totalCount,
    int? activeSlotIndex,
    bool? isToday,
    bool? isLoading,
  }) {
    return DayUiState(
      formattedDate: formattedDate ?? this.formattedDate,
      date: date ?? this.date,
      timeSlots: timeSlots ?? this.timeSlots,
      completionRate: completionRate ?? this.completionRate,
      filledCount: filledCount ?? this.filledCount,
      totalCount: totalCount ?? this.totalCount,
      activeSlotIndex: activeSlotIndex ?? this.activeSlotIndex,
      isToday: isToday ?? this.isToday,
      isLoading: isLoading ?? this.isLoading,
      prevDay: prevDay,
      nextDay: nextDay,
    );
  }
}

// ── Notifier ──
class DayNotifier extends Notifier<DayUiState> {
  late DateTime _selectedDate;

  @override
  DayUiState build() {
    _selectedDate = DateTime.now();

    // Kick off async loading and wire up refresh listener after build.
    Future.microtask(() {
      _load();
      ref.listen<int>(refreshSignalProvider, (_, __) => _load());
    });

    return DayUiState();
  }

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _weekdays = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  DayUiState _buildDayState({
    required UserPreferences prefs,
    required List<JournalEntry> entries,
    required DateTime date,
  }) {
    final slots = IntervalEngine.generateSlots(
      prefs: prefs,
      entries: entries,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    final isToday = selected == today;
    final activeIndex = isToday
        ? IntervalEngine.findActiveSlotIndex(slots, now)
        : -1;

    final filled = slots.where((s) => s.isFilled).length;
    final total = slots.length;
    final rate = total > 0 ? filled / total : 0.0;

    final diff = selected.difference(today).inDays;
    String formatted;
    if (diff == 0) {
      formatted = 'Today';
    } else if (diff == -1) {
      formatted = 'Yesterday';
    } else if (diff == 1) {
      formatted = 'Tomorrow';
    } else {
      formatted =
          '${_weekdays[date.weekday]}, ${_months[date.month]} ${date.day}';
    }

    return DayUiState(
      formattedDate: formatted,
      date: date,
      timeSlots: slots,
      completionRate: rate,
      filledCount: filled,
      totalCount: total,
      activeSlotIndex: activeIndex,
      isToday: isToday,
      isLoading: false,
    );
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(isLoading: true);

    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final journalRepo = ref.read(journalRepositoryProvider);
    final prefs = await prefsRepo.getPreferences();

    final prevDate = _selectedDate.subtract(const Duration(days: 1));
    final nextDate = _selectedDate.add(const Duration(days: 1));

    final results = await Future.wait([
      journalRepo.getEntriesForDate(prevDate),
      journalRepo.getEntriesForDate(_selectedDate),
      journalRepo.getEntriesForDate(nextDate),
    ]);

    final prev = _buildDayState(
        prefs: prefs, entries: results[0], date: prevDate);
    final current = _buildDayState(
        prefs: prefs, entries: results[1], date: _selectedDate);
    final next = _buildDayState(
        prefs: prefs, entries: results[2], date: nextDate);

    state = DayUiState(
      formattedDate: current.formattedDate,
      date: current.date,
      timeSlots: current.timeSlots,
      completionRate: current.completionRate,
      filledCount: current.filledCount,
      totalCount: current.totalCount,
      activeSlotIndex: current.activeSlotIndex,
      isToday: current.isToday,
      isLoading: false,
      prevDay: prev,
      nextDay: next,
    );
  }

  /// Instantly swap state to pre-loaded adjacent data for seamless animation.
  void navigateInstant({required bool forward}) {
    final adjacent = forward ? state.nextDay : state.prevDay;
    if (forward) {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    } else {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    }
    if (adjacent != null) {
      state = adjacent;
    }
    _load(showLoading: false);
  }

  void previousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    _load();
  }

  void nextDay() {
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    _load();
  }

  void goToDate(DateTime date) {
    _selectedDate = date;
    _load();
  }

  Future<void> refresh() async {
    await _load();
  }
}

final dayProvider = NotifierProvider<DayNotifier, DayUiState>(DayNotifier.new);
