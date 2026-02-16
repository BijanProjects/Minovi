import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/algorithm/interval_engine.dart';
import 'package:chronosense/core/di/providers.dart';
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
    );
  }
}

// ── Notifier ──
class DayNotifier extends StateNotifier<DayUiState> {
  final Ref ref;
  late DateTime _selectedDate;

  DayNotifier(this.ref) : super(DayUiState()) {
    _selectedDate = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);

    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final journalRepo = ref.read(journalRepositoryProvider);
    final prefs = await prefsRepo.getPreferences();
    final entries = await journalRepo.getEntriesForDate(_selectedDate);

    final slots = IntervalEngine.generateSlots(
      prefs: prefs,
      entries: entries,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isToday = selected == today;
    final activeIndex = isToday
        ? IntervalEngine.findActiveSlotIndex(slots, now)
        : -1;

    final filled = slots.where((s) => s.isFilled).length;
    final total = slots.length;
    final rate = total > 0 ? filled / total : 0.0;

    // Format date
    final diff = selected.difference(today).inDays;
    String formatted;
    if (diff == 0) {
      formatted = 'Today';
    } else if (diff == -1) {
      formatted = 'Yesterday';
    } else if (diff == 1) {
      formatted = 'Tomorrow';
    } else {
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      formatted = '${weekdays[_selectedDate.weekday]}, ${months[_selectedDate.month]} ${_selectedDate.day}';
    }

    state = DayUiState(
      formattedDate: formatted,
      date: _selectedDate,
      timeSlots: slots,
      completionRate: rate,
      filledCount: filled,
      totalCount: total,
      activeSlotIndex: activeIndex,
      isToday: isToday,
      isLoading: false,
    );
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

final dayProvider = StateNotifierProvider<DayNotifier, DayUiState>((ref) {
  return DayNotifier(ref);
});
