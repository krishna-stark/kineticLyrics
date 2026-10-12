import 'dart:io';

import 'package:path_provider/path_provider.dart';

class WhisperModelFiles {
  const WhisperModelFiles({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String tokens;
}

class WhisperModelPack {
  HttpClient? _activeClient;
  int _generation = 0;

  void cancel() {
    _generation++;
    _activeClient?.close(force: true);
    _activeClient = null;
  }

  static const _root =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main';

  Future<WhisperModelFiles> ensureInstalled({
    void Function(double progress)? onProgress,
  }) async {
    final generation = _generation;
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/models/whisper-base-int8');
    await directory.create(recursive: true);
    final files = <String, int>{
      'base-encoder.int8.onnx': 20 * 1024 * 1024,
      'base-decoder.int8.onnx': 110 * 1024 * 1024,
      'base-tokens.txt': 100 * 1024,
    };
    var finished = 0;
    for (final entry in files.entries) {
      if (generation != _generation) throw StateError('Download cancelled');
      final target = File('${directory.path}/${entry.key}');
      if (!await target.exists() || await target.length() < entry.value) {
        await _download('$_root/${entry.key}', target, (part) {
          onProgress?.call((finished + part) / files.length);
        });
      }
      if (generation != _generation) throw StateError('Download cancelled');
      if (await target.length() < entry.value) {
        throw const HttpException('Model download was incomplete. Retry.');
      }
      finished++;
      onProgress?.call(finished / files.length);
    }
    return WhisperModelFiles(
      encoder: '${directory.path}/base-encoder.int8.onnx',
      decoder: '${directory.path}/base-decoder.int8.onnx',
      tokens: '${directory.path}/base-tokens.txt',
    );
  }

  Future<void> _download(
    String source,
    File target,
    void Function(double progress) onProgress,
  ) async {
    final partial = File('${target.path}.download');
    if (await partial.exists()) await partial.delete();
    final client = HttpClient();
    _activeClient = client;
    IOSink? sink;
    try {
      final request = await client
          .getUrl(Uri.parse(source))
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, 'KineticLyrics/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Model download failed: ${response.statusCode}');
      }
      sink = partial.openWrite();
      var received = 0;
      await for (final bytes in response.timeout(const Duration(seconds: 30))) {
        received += bytes.length;
        sink.add(bytes);
        if (response.contentLength > 0) {
          onProgress(received / response.contentLength);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (response.contentLength > 0 && received != response.contentLength) {
        throw const HttpException('Model download was incomplete. Retry.');
      }
      await partial.rename(target.path);
    } finally {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
      if (identical(_activeClient, client)) _activeClient = null;
      client.close(force: true);
    }
  }
}
