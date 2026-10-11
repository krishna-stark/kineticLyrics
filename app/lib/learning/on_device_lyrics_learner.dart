import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../lyrics/domain/lyric_timeline.dart';
import '../lyrics/domain/track_identity.dart';
import 'generated_lyrics_store.dart';
import 'on_device_recognition_worker.dart';
import 'playback_pcm_capture.dart';
import 'whisper_model_pack.dart';

enum LearningState {
  idle,
  preparingModel,
  awaitingCapturePermission,
  listening,
  finalizing,
  learned,
  unavailable,
}

class LearningStatus {
  const LearningStatus(
    this.state, {
    this.progress = 0,
    this.message,
    this.partialTimeline,
  });

  final LearningState state;
  final double progress;
  final String? message;
  final LyricTimeline? partialTimeline;
}

abstract interface class LyricsLearner {
  Stream<LearningStatus> get statuses;
  Future<void> start(TrackIdentity track, Duration currentPosition);
  Future<LyricTimeline?> finish({bool stopCapture = false});
  Future<void> dispose();
}

class OnDeviceLyricsLearner implements LyricsLearner {
  OnDeviceLyricsLearner({
    required this.store,
    PlaybackPcmCapture? capture,
    WhisperModelPack? models,
  }) : _capture = capture ?? PlaybackPcmCapture(),
       _models = models ?? WhisperModelPack();

  // Whisper needs enough musical context to separate a sung phrase from the
  // backing track. Two-second clips frequently returned an empty transcript.
  static const _windowSamples = 16000 * 6;

  final GeneratedLyricsStore store;
  final PlaybackPcmCapture _capture;
  final WhisperModelPack _models;
  final _status = StreamController<LearningStatus>.broadcast();
  final List<double> _buffer = [];
  final List<_TranscriptSection> _sections = [];
  final List<Future<void>> _pending = [];
  StreamSubscription<PcmChunk>? _audioSubscription;
  OnDeviceRecognitionWorker? _worker;
  TrackIdentity? _track;
  Duration _captureStart = Duration.zero;
  var _submittedSamples = 0;
  var _generation = 0;
  Future<LyricTimeline?>? _finishing;

  @override
  Stream<LearningStatus> get statuses => _status.stream;

  @override
  Future<void> start(TrackIdentity track, Duration currentPosition) async {
    if (_track?.cacheKey == track.cacheKey) return;
    await finish(stopCapture: true);
    if (_track != null) return;
    final generation = ++_generation;
    _track = track;
    _captureStart = currentPosition;
    _submittedSamples = 0;
    _sections.clear();
    _buffer.clear();
    _emit(const LearningStatus(LearningState.preparingModel));
    try {
      final files = await _models.ensureInstalled(
        onProgress: (progress) {
          if (generation == _generation) {
            _emit(
              LearningStatus(LearningState.preparingModel, progress: progress),
            );
          }
        },
      );
      if (generation != _generation) return;
      final worker = await OnDeviceRecognitionWorker.start(files);
      if (generation != _generation) {
        await worker.dispose();
        return;
      }
      _worker = worker;
      _audioSubscription = _capture.chunks.listen(_onPcm);
      _emit(const LearningStatus(LearningState.awaitingCapturePermission));
      await _capture.start();
      if (generation != _generation) {
        await _capture.stop();
        return;
      }
      _emit(
        const LearningStatus(
          LearningState.listening,
          message: 'Listening locally — the first line can take 6–10 seconds.',
        ),
      );
    } catch (error) {
      if (generation != _generation) return;
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _capture.stop();
      await _worker?.dispose();
      _worker = null;
      _track = null;
      _emit(
        LearningStatus(
          LearningState.unavailable,
          message: _friendlyLearningError(error),
        ),
      );
    }
  }

  void _onPcm(PcmChunk chunk) {
    if (chunk.sampleRate != 16000 || _worker == null || _finishing != null) {
      return;
    }
    _buffer.addAll(chunk.samples);
    while (_buffer.length >= _windowSamples) {
      final samples = Float32List.fromList(
        _buffer.take(_windowSamples).toList(),
      );
      _buffer.removeRange(0, _windowSamples);
      _submit(samples);
    }
  }

  void _submit(Float32List samples) {
    final worker = _worker;
    if (worker == null) return;
    final offset =
        _captureStart +
        Duration(milliseconds: _submittedSamples * 1000 ~/ 16000);
    final duration = Duration(milliseconds: samples.length * 1000 ~/ 16000);
    _submittedSamples += samples.length;
    final job = worker
        .recognize(samples)
        .then((result) {
          final text = _clean(result.text);
          if (text.isNotEmpty && !_looksRepetitive(text)) {
            _sections.add(
              _TranscriptSection(
                text,
                offset,
                duration,
                _timedWords(result, text, offset, duration),
              ),
            );
            _emit(
              LearningStatus(
                LearningState.listening,
                message: 'On-device lyrics are appearing live.',
                partialTimeline: _buildTimeline(),
              ),
            );
          } else {
            _emit(
              const LearningStatus(
                LearningState.listening,
                message: 'Listening for a clear vocal phrase…',
              ),
            );
          }
        })
        .catchError((Object error) {
          _emit(
            LearningStatus(
              LearningState.unavailable,
              message: _friendlyLearningError(error, duringRecognition: true),
            ),
          );
        });
    _pending.add(job);
    job.whenComplete(() => _pending.remove(job));
  }

  @override
  Future<LyricTimeline?> finish({bool stopCapture = false}) {
    return _finishing ??= _finish(
      stopCapture: stopCapture,
    ).whenComplete(() => _finishing = null);
  }

  Future<LyricTimeline?> _finish({required bool stopCapture}) async {
    _generation++;
    _models.cancel();
    final track = _track;
    try {
      if (stopCapture) await _capture.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      if (track == null) return null;
      _emit(const LearningStatus(LearningState.finalizing));
      if (_buffer.length >= 16000) _submit(Float32List.fromList(_buffer));
      _buffer.clear();
      await Future.wait(List.of(_pending)).catchError((_) => <void>[]);
      final timeline = _buildTimeline();
      if (timeline != null) {
        await store.save(track, timeline);
        _emit(const LearningStatus(LearningState.learned));
      } else {
        _emit(const LearningStatus(LearningState.unavailable));
      }
      return timeline;
    } catch (error) {
      _emit(
        LearningStatus(
          LearningState.unavailable,
          message: _friendlyLearningError(error),
        ),
      );
      return null;
    } finally {
      _buffer.clear();
      await _worker?.dispose();
      _worker = null;
      _track = null;
    }
  }

  LyricTimeline? _buildTimeline() {
    _sections.sort((a, b) => a.start.compareTo(b.start));
    final lines = <LyricLine>[];
    for (final section in _sections) {
      final words = section.words;
      if (words.isEmpty) continue;
      const perLine = 7;
      for (var start = 0; start < words.length; start += perLine) {
        final group = words.skip(start).take(perLine).toList();
        final lineStart = group.first.start;
        final lineEnd = group.last.end;
        lines.add(
          LyricLine(
            text: group.map((word) => word.text).join(' '),
            start: lineStart,
            end: lineEnd,
            words: group,
            confidence: .68,
            provenance: TimingProvenance.speechRecognition,
          ),
        );
      }
    }
    if (lines.isEmpty) return null;
    return LyricTimeline(
      provider: store.id,
      quality: LyricsTimingQuality.estimated,
      lines: lines,
    );
  }

  String _clean(String value) => value
      .replaceAll(RegExp(r'\[[^\]]+\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _looksRepetitive(String value) {
    final words = value.toLowerCase().split(' ');
    if (words.length < 6) return false;
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }
    return counts.values.reduce((a, b) => a > b ? a : b) / words.length > .55;
  }

  List<LyricWord> _timedWords(
    RecognitionResult result,
    String text,
    Duration offset,
    Duration duration,
  ) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final timestamps = result.timestamps
        .where((value) => value.isFinite && value >= 0)
        .toList();
    final usableTimestamps = timestamps.length >= words.length
        ? timestamps.take(words.length).toList()
        : const <double>[];
    return [
      for (var index = 0; index < words.length; index++)
        (() {
          final relativeStart = usableTimestamps.isEmpty
              ? _fraction(duration, index, words.length)
              : Duration(
                  milliseconds: (usableTimestamps[index] * 1000).round(),
                );
          final relativeEnd = usableTimestamps.isEmpty
              ? _fraction(duration, index + 1, words.length)
              : index + 1 < usableTimestamps.length
              ? Duration(
                  milliseconds: (usableTimestamps[index + 1] * 1000).round(),
                )
              : duration;
          final safeEnd = relativeEnd > relativeStart
              ? relativeEnd
              : relativeStart + const Duration(milliseconds: 120);
          return LyricWord(
            text: words[index],
            start: offset + relativeStart,
            end: offset + safeEnd,
            confidence: usableTimestamps.isEmpty ? .48 : .72,
            provenance: usableTimestamps.isEmpty
                ? TimingProvenance.estimated
                : TimingProvenance.speechRecognition,
          );
        })(),
    ];
  }

  void _emit(LearningStatus value) {
    if (!_status.isClosed) _status.add(value);
  }

  @override
  Future<void> dispose() async {
    await finish(stopCapture: true);
    await _status.close();
  }

  Duration _fraction(Duration value, int numerator, int denominator) =>
      Duration(microseconds: value.inMicroseconds * numerator ~/ denominator);
}

String _friendlyLearningError(Object error, {bool duringRecognition = false}) {
  if (error is FileSystemException) {
    return 'The model or saved lyrics could not be accessed. Check free storage and retry.';
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('permission') ||
      detail.contains('denied') ||
      detail.contains('capture')) {
    return 'Audio capture was not allowed. Retry and approve the Android prompt.';
  }
  if (detail.contains('space') ||
      detail.contains('storage') ||
      detail.contains('disk')) {
    return 'Not enough storage for the on-device lyric model.';
  }
  if (detail.contains('socket') ||
      detail.contains('network') ||
      detail.contains('host') ||
      detail.contains('http')) {
    return 'The AI model could not be downloaded. Check your connection and retry.';
  }
  if (duringRecognition) {
    return 'The on-device lyric engine stopped. Retry when the song is playing clearly.';
  }
  return 'On-device lyrics could not start. Check that the song is playing and retry.';
}

class _TranscriptSection {
  const _TranscriptSection(this.text, this.start, this.duration, this.words);

  final String text;
  final Duration start;
  final Duration duration;
  final List<LyricWord> words;
}
