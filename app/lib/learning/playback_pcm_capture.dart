import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/services.dart';

class PcmChunk {
  const PcmChunk({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;
}

class PlaybackPcmCapture {
  static const _events = EventChannel('kinetic_lyrics/pcm/events');
  static const _methods = MethodChannel('kinetic_lyrics/pcm/methods');

  late final Stream<Map<Object?, Object?>> _rawEvents = _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<Object?, Object?>.from(event as Map))
      .asBroadcastStream();

  late final Stream<PcmChunk> chunks = _rawEvents
      .where((event) => event['state'] == 'pcm')
      .map((event) {
        final map = event;
        final bytes = map['samples']! as Uint8List;
        final values = ByteData.sublistView(bytes);
        final samples = Float32List(bytes.length ~/ 2);
        for (var index = 0; index < samples.length; index++) {
          samples[index] = values.getInt16(index * 2, Endian.little) / 32768;
        }
        return PcmChunk(
          samples: samples,
          sampleRate: map['sampleRate']! as int,
        );
      })
      .asBroadcastStream();

  Future<void> start({String? sourcePackage}) async {
    final ready = Completer<void>();
    late final StreamSubscription<Map<Object?, Object?>> subscription;
    subscription = _rawEvents.listen(
      (event) {
        switch (event['state']) {
          case 'capturing':
            if (!ready.isCompleted) ready.complete();
          case 'denied':
            if (!ready.isCompleted) {
              ready.completeError(
                StateError('Playback capture permission was not granted.'),
              );
            }
          case 'stopped':
            if (!ready.isCompleted) {
              ready.completeError(StateError('Playback capture stopped.'));
            }
        }
      },
      onError: (Object error) {
        if (!ready.isCompleted) ready.completeError(error);
      },
    );
    try {
      await _methods.invokeMethod<void>('startCapture', {
        'sourcePackage': sourcePackage,
      });
      await ready.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for Android playback capture.',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stopCapture');
    } on MissingPluginException {
      // Unsupported platforms simply retain the abstract visualizer.
    }
  }
}
