/// Abstract interface for on-device AI text generation.
///
/// Implementations use MediaPipe LLM Inference (Gemma 2B) running
/// entirely on the device — no data ever leaves the phone.
abstract class OnDeviceAiService {
  /// Whether the on-device model is loaded and ready for inference.
  Future<bool> isAvailable();

  /// Generate a natural-language report from a structured prompt.
  Future<String> generateInsight(String structuredData);

  /// Start downloading + loading the model. Completes when the model
  /// is ready (may take minutes on a slow connection). Watch
  /// [downloadProgress] for real-time progress while this is running.
  Future<bool> prepareModel();

  /// Cancel an in-progress download.
  Future<void> cancelDownload();

  /// Stream of download progress values in the range 0.0–1.0.
  /// Emits nothing when no download is active.
  Stream<double> get downloadProgress;

  /// Current lifecycle status of the model.
  Future<AiModelStatus> getStatus();
}

enum AiModelStatus {
  /// Model has never been downloaded.
  notDownloaded,

  /// Model file is on disk but data is still transferring.
  downloading,

  /// Model file is present on disk (may or may not be loaded).
  downloaded,

  /// Model is loaded into memory and ready for inference.
  ready,

  /// Device does not meet the hardware requirements.
  unsupported,

  /// Something went wrong.
  error,
}

