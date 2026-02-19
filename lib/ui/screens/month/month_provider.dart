import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/di/refresh_signal.dart';
import 'package:chronosense/domain/model/models.dart';

// ── State ──
class MonthUiState {
  final DateTime month; // first day of month
  final String formattedMonth;
  final MonthInsight? insight;
  final bool isLoading;
  final MonthUiState? prevMonth;
  final MonthUiState? nextMonth;

  MonthUiState({
    DateTime? month,
    this.formattedMonth = '',
    this.insight,
    this.isLoading = true,
    this.prevMonth,
    this.nextMonth,
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
      prevMonth: prevMonth,
      nextMonth: nextMonth,
    );
  }
}

// ── Notifier ──
class MonthNotifier extends Notifier<MonthUiState> {
  late DateTime _currentMonth;

  @override
  MonthUiState build() {
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);

    Future.microtask(() {
      _load();
      ref.listen<int>(refreshSignalProvider, (_, __) => _load());
    });

    return MonthUiState();
  }

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  MonthUiState _buildMonthState({
    required UserPreferences prefs,
    required List<JournalEntry> entries,
    required DateTime month,
  }) {
    final insight = MonthInsight.aggregate(
      entries: entries,
      totalSlotsPerDay: prefs.totalSlots,
    );
    final formatted = '${_months[month.month]} ${month.year}';
    return MonthUiState(
      month: month,
      formattedMonth: formatted,
      insight: insight,
      isLoading: false,
    );
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) state = state.copyWith(isLoading: true);

    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final journalRepo = ref.read(journalRepositoryProvider);
    final prefs = await prefsRepo.getPreferences();

    final prevM = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    final nextM = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);

    final results = await Future.wait([
      journalRepo.getEntriesForDateRange(
          prevM, DateTime(prevM.year, prevM.month + 1, 0)),
      journalRepo.getEntriesForDateRange(
          _currentMonth,
          DateTime(_currentMonth.year, _currentMonth.month + 1, 0)),
      journalRepo.getEntriesForDateRange(
          nextM, DateTime(nextM.year, nextM.month + 1, 0)),
    ]);

    final prev =
        _buildMonthState(prefs: prefs, entries: results[0], month: prevM);
    final current = _buildMonthState(
        prefs: prefs, entries: results[1], month: _currentMonth);
    final next =
        _buildMonthState(prefs: prefs, entries: results[2], month: nextM);

    state = MonthUiState(
      month: current.month,
      formattedMonth: current.formattedMonth,
      insight: current.insight,
      isLoading: false,
      prevMonth: prev,
      nextMonth: next,
    );
  }

  /// Instantly swap state to pre-loaded adjacent data for seamless animation.
  void navigateInstant({required bool forward}) {
    final adjacent = forward ? state.nextMonth : state.prevMonth;
    if (forward) {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    } else {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    }
    if (adjacent != null) {
      state = adjacent;
    }
    _load(showLoading: false);
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

final monthProvider = NotifierProvider<MonthNotifier, MonthUiState>(
  MonthNotifier.new,
);
