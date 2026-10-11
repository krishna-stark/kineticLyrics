import 'dart:async';

import 'package:flutter/services.dart';

import 'audio_features.dart';

abstract interface class AudioAnalyzer {
  Stream<AudioFeatures> get frames;
  Future<void> requestAccess();
  void dispose();
}

class PlatformAudioAnalyzer implements AudioAnalyzer {
  static const _events = EventChannel('kinetic_lyrics/audio/events');
  static const _methods = MethodChannel('kinetic_lyrics/audio/methods');

  late final Stream<AudioFeatures> _frames = _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => AudioFeatures.fromMap(event as Map<Object?, Object?>))
      .handleError((_) {})
      .asBroadcastStream();

  @override
  Stream<AudioFeatures> get frames => _frames;

  @override
  Future<void> requestAccess() async {
    try {
      await _methods.invokeMethod<void>('requestAccess');
    } on MissingPluginException {
      // iOS and unsupported platforms keep timestamp-driven motion.
    }
  }

  @override
  void dispose() {}
}

class SilentAudioAnalyzer implements AudioAnalyzer {
  const SilentAudioAnalyzer();

  @override
  Stream<AudioFeatures> get frames => const Stream.empty();

  @override
  Future<void> requestAccess() async {}

  @override
  void dispose() {}
}
