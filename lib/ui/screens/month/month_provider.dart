import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class MonthUiState {
  final DateTime month; // first day of month
  final String formattedMonth;
  final MonthInsight? insight;
  final bool isLoading;

  MonthUiState({
    DateTime? month,
    this.formattedMonth = '',
    this.insight,
    this.isLoading = true,
  }) : month = month ?? DateTime.now();

  MonthUiState copyWith({
    DateTime? month,
    String? formattedMonth,
    MonthInsight? insight,
    bool? isLoading,
  }) {
    return MonthUiState(
      month: month ?? this.month,
      formattedMonth: formattedMonth ?? this.formattedMonth,
      insight: insight ?? this.insight,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ──
class MonthNotifier extends StateNotifier<MonthUiState> {
  final Ref ref;
  late DateTime _currentMonth;

  MonthNotifier(this.ref) : super(MonthUiState()) {
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);

    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final journalRepo = ref.read(journalRepositoryProvider);

    final prefs = await prefsRepo.getPreferences();

    // Date range for the month
    final start = _currentMonth;
    final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final entries = await journalRepo.getEntriesForDateRange(start, end);

    final insight = MonthInsight.aggregate(
      entries: entries,
      totalSlotsPerDay: prefs.totalSlots,
    );

    final formatted = '${_months[_currentMonth.month]} ${_currentMonth.year}';

    state = MonthUiState(
      month: _currentMonth,
      formattedMonth: formatted,
      insight: insight,
      isLoading: false,
    );
  }

  void previousMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    _load();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    _load();
  }

  Future<void> refresh() async => _load();
}

final monthProvider = StateNotifierProvider<MonthNotifier, MonthUiState>(
  (ref) => MonthNotifier(ref),
);
