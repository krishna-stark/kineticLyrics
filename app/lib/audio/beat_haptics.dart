import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BeatHaptics {
  static const _channel = MethodChannel('kinetic_lyrics/haptics');

  static Future<bool> pulse() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return await _channel.invokeMethod<bool>('pulse') ?? false;
      }
      await HapticFeedback.mediumImpact();
      return true;
    } catch (_) {
      return false;
    }
  }
}
