import 'package:flutter/services.dart';

/// Commands and scalar telemetry only. PCM never crosses this channel.
class VoiceAudio {
  static const channel = MethodChannel('hu.sajathang/audio');

  Future<Map<String, dynamic>> command(
    String name, [
    Map<String, Object?>? arguments,
  ]) async {
    final value = await channel.invokeMapMethod<String, dynamic>(
      name,
      arguments,
    );
    return value ?? <String, dynamic>{};
  }
}
