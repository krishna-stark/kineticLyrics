import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'whisper_model_pack.dart';

class RecognitionResult {
  const RecognitionResult({
    required this.text,
    required this.tokens,
    required this.timestamps,
  });

  final String text;
  final List<String> tokens;
  final List<double> timestamps;
}

class OnDeviceRecognitionWorker {
  OnDeviceRecognitionWorker._();

  final ReceivePort _receive = ReceivePort();
  final Map<int, Completer<RecognitionResult>> _pending = {};
  SendPort? _commands;
  Isolate? _isolate;
  StreamSubscription<Object?>? _subscription;
  var _nextId = 0;

  static Future<OnDeviceRecognitionWorker> start(
    WhisperModelFiles files,
  ) async {
    final worker = OnDeviceRecognitionWorker._();
    final ready = Completer<void>();
    worker._subscription = worker._receive.listen((message) {
      if (message is SendPort) {
        worker._commands = message;
        ready.complete();
        return;
      }
      if (message is Map) {
        final id = message['id'] as int;
        final completer = worker._pending.remove(id);
        if (completer == null) return;
        if (message['error'] case final String error) {
          completer.completeError(StateError(error));
        } else {
          completer.complete(
            RecognitionResult(
              text: message['text'] as String? ?? '',
              tokens: (message['tokens'] as List?)?.cast<String>() ?? const [],
              timestamps:
                  (message['timestamps'] as List?)?.cast<double>() ?? const [],
            ),
          );
        }
      }
    });
    worker._isolate = await Isolate.spawn(_recognitionIsolate, {
      'reply': worker._receive.sendPort,
      'encoder': files.encoder,
      'decoder': files.decoder,
      'tokens': files.tokens,
    });
    await ready.future.timeout(const Duration(seconds: 20));
    return worker;
  }

  Future<RecognitionResult> recognize(Float32List samples) {
    final id = _nextId++;
    final completer = Completer<RecognitionResult>();
    _pending[id] = completer;
    _commands!.send({'id': id, 'samples': samples});
    return completer.future;
  }

  Future<void> dispose() async {
    _commands?.send('stop');
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    for (final pending in _pending.values) {
      pending.completeError(StateError('Recognition stopped'));
    }
    _pending.clear();
    await _subscription?.cancel();
    _receive.close();
  }
}

void _recognitionIsolate(Map<String, Object?> setup) {
  final reply = setup['reply']! as SendPort;
  final commands = ReceivePort();
  try {
    sherpa.initBindings();
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: setup['encoder']! as String,
            decoder: setup['decoder']! as String,
            language: '',
            task: 'transcribe',
            tailPaddings: 300,
            enableSegmentTimestamps: true,
          ),
          tokens: setup['tokens']! as String,
          numThreads: 2,
          debug: false,
          modelType: 'whisper',
        ),
      ),
    );
    reply.send(commands.sendPort);
    commands.listen((message) {
      if (message == 'stop') {
        recognizer.free();
        commands.close();
        Isolate.exit();
      }
      if (message is! Map) return;
      final id = message['id']! as int;
      try {
        final stream = recognizer.createStream();
        stream.acceptWaveform(
          samples: message['samples']! as Float32List,
          sampleRate: 16000,
        );
        recognizer.decode(stream);
        final result = recognizer.getResult(stream);
        stream.free();
        reply.send({
          'id': id,
          'text': result.text,
          'tokens': result.tokens,
          'timestamps': result.timestamps,
        });
      } catch (error) {
        reply.send({'id': id, 'error': error.toString()});
      }
    });
  } catch (error) {
    reply.send(commands.sendPort);
    commands.listen((message) {
      if (message is Map) {
        reply.send({'id': message['id'], 'error': error.toString()});
      }
    });
  }
}
