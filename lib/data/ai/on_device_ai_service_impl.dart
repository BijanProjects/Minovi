import 'package:flutter/services.dart';
import 'package:chronosense/domain/service/on_device_ai_service.dart';

/// Platform-channel implementation of [OnDeviceAiService].
///
/// Communicates with the Android native layer which hosts the
/// MediaPipe LLM Inference API running a Gemma 2B model on-device.
/// All data stays entirely on the device — nothing is sent to the cloud.
class OnDeviceAiServiceImpl implements OnDeviceAiService {
  static const _channel =
      MethodChannel('com.chronosense/on_device_ai');
  static const _progressChannel =
      EventChannel('com.chronosense/on_device_ai_progress');

  OnDeviceAiServiceImpl._();
  static final OnDeviceAiServiceImpl instance = OnDeviceAiServiceImpl._();

  @override
  Stream<double> get downloadProgress =>
      _progressChannel
          .receiveBroadcastStream()
          .where((v) => v is double || v is int)
          .map((v) => (v as num).toDouble());

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> generateInsight(String structuredData) async {
    try {
      return await _channel.invokeMethod<String>(
            'generateInsight',
            {'prompt': structuredData},
          ) ??
          '';
    } on PlatformException catch (e) {
      throw Exception('On-device AI generation failed: ${e.message}');
    } on MissingPluginException {
      throw Exception('On-device AI is not available on this platform.');
    }
  }

  @override
  Future<bool> prepareModel() async {
    try {
      return await _channel.invokeMethod<bool>('prepareModel') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> cancelDownload() async {
    try {
      await _channel.invokeMethod<void>('cancelDownload');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }

  @override
  Future<AiModelStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod<String>('getStatus');
      return switch (result) {
        'ready'          => AiModelStatus.ready,
        'downloading'    => AiModelStatus.downloading,
        'downloaded'     => AiModelStatus.downloaded,
        'not_downloaded' => AiModelStatus.notDownloaded,
        'unsupported'    => AiModelStatus.unsupported,
        _                => AiModelStatus.error,
      };
    } on PlatformException {
      return AiModelStatus.error;
    } on MissingPluginException {
      return AiModelStatus.unsupported;
    }
  }
}
