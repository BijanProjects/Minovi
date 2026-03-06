import 'package:chronosense/domain/model/insight_report.dart';

/// Abstract interface for on-device AI text generation.
///
/// Implementations can use MediaPipe LLM Inference (Gemma), Google AI Edge,
/// or any other on-device model. All data stays on the device.
abstract class OnDeviceAiService {
  /// Whether the on-device model is available and ready.
  Future<bool> isAvailable();

  /// Generate a natural-language insight report from structured analysis data.
  ///
  /// [structuredData] is a pre-built prompt containing the analysis results.
  /// Returns the LLM-generated narrative text.
  Future<String> generateInsight(String structuredData);

  /// Download / prepare the on-device model if not yet available.
  /// Returns true if successful.
  Future<bool> prepareModel();

  /// Current status of the model.
  Future<AiModelStatus> getStatus();
}

enum AiModelStatus {
  /// Model is not downloaded yet.
  notDownloaded,

  /// Model is being downloaded.
  downloading,

  /// Model is ready to use.
  ready,

  /// Device does not support on-device inference.
  unsupported,

  /// An error occurred.
  error,
}
