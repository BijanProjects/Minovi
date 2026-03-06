import 'package:flutter/services.dart';
import 'package:chronosense/domain/service/on_device_ai_service.dart';

/// Platform-channel implementation of [OnDeviceAiService].
///
/// Communicates with the Android native layer which hosts the
/// MediaPipe LLM Inference API running a Gemma 2B model on-device.
/// All data stays entirely on the device — nothing is sent to the cloud.
class OnDeviceAiServiceImpl implements OnDeviceAiService {
  static const _channel = MethodChannel('com.chronosense/on_device_ai');

  OnDeviceAiServiceImpl._();
  static final OnDeviceAiServiceImpl instance = OnDeviceAiServiceImpl._();

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> generateInsight(String structuredData) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'generateInsight',
        {'prompt': structuredData},
      );
      return result ?? '';
    } on PlatformException catch (e) {
      throw Exception('On-device AI generation failed: ${e.message}');
    } on MissingPluginException {
      throw Exception('On-device AI is not available on this platform.');
    }
  }

  @override
  Future<bool> prepareModel() async {
    try {
      final result = await _channel.invokeMethod<bool>('prepareModel');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<AiModelStatus> getStatus() async {
    try {
      final result = await _channel.invokeMethod<String>('getStatus');
      return switch (result) {
        'ready' => AiModelStatus.ready,
        'downloading' => AiModelStatus.downloading,
        'not_downloaded' => AiModelStatus.notDownloaded,
        'unsupported' => AiModelStatus.unsupported,
        _ => AiModelStatus.error,
      };
    } on PlatformException {
      return AiModelStatus.error;
    } on MissingPluginException {
      return AiModelStatus.unsupported;
    }
  }
}
