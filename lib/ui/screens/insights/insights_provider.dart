import 'dart:async';
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

  /// Download progress 0.0–1.0, null when not downloading.
  final double? downloadProgress;

  InsightsState({
    this.isLoading = false,
    this.report,
    this.error,
    this.aiStatus = AiModelStatus.notDownloaded,
    DateRange? dateRange,
    this.downloadProgress,
  }) : dateRange = dateRange ?? DateRange.twoWeeksRange();

  InsightsState copyWith({
    bool? isLoading,
    InsightReport? report,
    String? error,
    AiModelStatus? aiStatus,
    DateRange? dateRange,
    double? downloadProgress,
    bool clearDownloadProgress = false,
  }) {
    return InsightsState(
      isLoading: isLoading ?? this.isLoading,
      report: report ?? this.report,
      error: error,
      aiStatus: aiStatus ?? this.aiStatus,
      dateRange: dateRange ?? this.dateRange,
      downloadProgress:
          clearDownloadProgress ? null : (downloadProgress ?? this.downloadProgress),
    );
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  DateRange({required this.start, required this.end, required this.label});

  static DateRange lastWeek() {
    final today = _today();
    return DateRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
      label: 'Last 7 Days',
    );
  }

  static DateRange lastMonth() {
    final today = _today();
    return DateRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
      label: 'Last 30 Days',
    );
  }

  static DateRange twoWeeksRange() {
    final today = _today();
    return DateRange(
      start: today.subtract(const Duration(days: 13)),
      end: today,
      label: 'Last 2 Weeks',
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

// ── Provider ───────────────────────────────────────────────────────

final insightsProvider =
    NotifierProvider<InsightsNotifier, InsightsState>(InsightsNotifier.new);

class InsightsNotifier extends Notifier<InsightsState> {
  final OnDeviceAiService _aiService = OnDeviceAiServiceImpl.instance;
  StreamSubscription<double>? _progressSub;

  @override
  InsightsState build() {
    // Clean up subscription when the provider is disposed
    ref.onDispose(() => _progressSub?.cancel());
    return InsightsState();
  }

  // ── Report generation ─────────────────────────────────────────────

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

      // Deterministic analysis — always runs, always has results
      final report = InsightsEngine.analyse(
        entries: entries,
        rangeStart: range.start,
        rangeEnd: range.end,
      );

      // Try to enhance with on-device LLM (optional, silent fallback)
      if (await _aiService.isAvailable()) {
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
          // LLM inference failed — fall through to template report
        }
      }

      state = state.copyWith(isLoading: false, report: report);
      final aiStatus = await _aiService.getStatus();
      state = state.copyWith(aiStatus: aiStatus);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate report: $e',
      );
    }
  }

  Future<void> setDateRange(DateRange range) async {
    state = state.copyWith(dateRange: range);
    await generateReport();
  }

  // ── Model download ────────────────────────────────────────────────

  /// Start downloading the on-device model. Subscribes to the native
  /// progress stream so the UI stays updated during the download.
  Future<void> prepareModel() async {
    state = state.copyWith(
      aiStatus: AiModelStatus.downloading,
      downloadProgress: 0.0,
    );

    // Subscribe to the per-second progress events from Android
    await _progressSub?.cancel();
    _progressSub = _aiService.downloadProgress.listen(
      (progress) {
        state = state.copyWith(downloadProgress: progress);
      },
      onError: (_) {
        _progressSub?.cancel();
      },
    );

    final success = await _aiService.prepareModel();
    await _progressSub?.cancel();
    _progressSub = null;

    final newStatus = await _aiService.getStatus();
    state = state.copyWith(
      aiStatus: newStatus,
      clearDownloadProgress: true,
    );

    if (success && state.report != null) {
      await generateReport();
    }
  }

  Future<void> cancelDownload() async {
    await _aiService.cancelDownload();
    await _progressSub?.cancel();
    _progressSub = null;
    state = state.copyWith(
      aiStatus: AiModelStatus.notDownloaded,
      clearDownloadProgress: true,
    );
  }
}
