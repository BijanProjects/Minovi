import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/core/di/providers.dart';
import 'package:chronosense/core/algorithm/insights_engine.dart';
import 'package:chronosense/data/ai/on_device_ai_service_impl.dart';
import 'package:chronosense/data/ai/prompt_builder.dart';
import 'package:chronosense/domain/model/insight_report.dart';
import 'package:chronosense/domain/service/on_device_ai_service.dart';

// ── State ──────────────────────────────────────────────────────────

class InsightsState {
  final bool isLoading;
  final InsightReport? report;
  final String? error;
  final AiModelStatus aiStatus;
  final DateRange dateRange;

  InsightsState({
    this.isLoading = false,
    this.report,
    this.error,
    this.aiStatus = AiModelStatus.notDownloaded,
    DateRange? dateRange,
  }) : dateRange = dateRange ?? DateRange.twoWeeksRange();

  InsightsState copyWith({
    bool? isLoading,
    InsightReport? report,
    String? error,
    AiModelStatus? aiStatus,
    DateRange? dateRange,
  }) {
    return InsightsState(
      isLoading: isLoading ?? this.isLoading,
      report: report ?? this.report,
      error: error,
      aiStatus: aiStatus ?? this.aiStatus,
      dateRange: dateRange ?? this.dateRange,
    );
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  DateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  static DateRange lastWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
      label: 'Last 7 Days',
    );
  }

  static DateRange lastMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
      label: 'Last 30 Days',
    );
  }

  static DateRange twoWeeksRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateRange(
      start: today.subtract(const Duration(days: 13)),
      end: today,
      label: 'Last 2 Weeks',
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────

final insightsProvider =
    NotifierProvider<InsightsNotifier, InsightsState>(
  InsightsNotifier.new,
);

class InsightsNotifier extends Notifier<InsightsState> {
  final OnDeviceAiService _aiService = OnDeviceAiServiceImpl.instance;

  @override
  InsightsState build() {
    return InsightsState();
  }

  /// Generate the insight report for the current date range.
  Future<void> generateReport() async {
    final range = state.dateRange;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repo = ref.read(journalRepositoryProvider);
      final entries = await repo.getEntriesForDateRange(range.start, range.end);

      if (entries.isEmpty || entries.where((e) => e.hasContent).isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No tracked entries found for this period. '
              'Start tracking your time to get insights!',
        );
        return;
      }

      // Run the deterministic analysis engine
      final report = InsightsEngine.analyse(
        entries: entries,
        rangeStart: range.start,
        rangeEnd: range.end,
      );

      // Try to enhance with on-device LLM
      final aiAvailable = await _aiService.isAvailable();
      if (aiAvailable) {
        try {
          final prompt = PromptBuilder.buildInsightPrompt(
            report: report,
            entries: entries,
          );
          final narrative = await _aiService.generateInsight(prompt);
          if (narrative.isNotEmpty) {
            state = state.copyWith(
              isLoading: false,
              report: InsightReport(
                generatedAt: report.generatedAt,
                rangeStart: report.rangeStart,
                rangeEnd: report.rangeEnd,
                totalEntries: report.totalEntries,
                activeDays: report.activeDays,
                totalTrackedMinutes: report.totalTrackedMinutes,
                timeByActivity: report.timeByActivity,
                moodFrequency: report.moodFrequency,
                moodTimeline: report.moodTimeline,
                correlations: report.correlations,
                patterns: report.patterns,
                narrative: narrative,
                isLlmGenerated: true,
              ),
            );
            return;
          }
        } catch (_) {
          // LLM failed — fall back to template report
        }
      }

      // Use template-based report
      state = state.copyWith(isLoading: false, report: report);

      // Check AI status for UI display
      final aiStatus = await _aiService.getStatus();
      state = state.copyWith(aiStatus: aiStatus);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate report: $e',
      );
    }
  }

  /// Change the date range and regenerate.
  Future<void> setDateRange(DateRange range) async {
    state = state.copyWith(dateRange: range);
    await generateReport();
  }

  /// Try to prepare / download the on-device model.
  Future<void> prepareModel() async {
    state = state.copyWith(aiStatus: AiModelStatus.downloading);
    final success = await _aiService.prepareModel();
    final newStatus = await _aiService.getStatus();
    state = state.copyWith(aiStatus: newStatus);
    if (success && state.report != null) {
      // Re-generate with LLM
      await generateReport();
    }
  }
}
