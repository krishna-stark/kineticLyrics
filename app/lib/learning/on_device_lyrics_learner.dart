import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../lyrics/domain/lyric_timeline.dart';
import '../lyrics/domain/track_identity.dart';
import 'generated_lyrics_store.dart';
import 'on_device_recognition_worker.dart';
import 'playback_pcm_capture.dart';
import 'whisper_model_pack.dart';
import 'transcript_quality.dart';

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
    this.trackKey,
  });

  final LearningState state;
  final double progress;
  final String? message;
  final LyricTimeline? partialTimeline;
  final String? trackKey;
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
    Future<RecognitionWorker> Function(WhisperModelFiles)? workerFactory,
    DateTime Function()? now,
    this.watchdogInterval = const Duration(seconds: 1),
  }) : _capture = capture ?? PlaybackPcmCapture(),
       _models = models ?? WhisperModelPack(),
       _workerFactory = workerFactory ?? OnDeviceRecognitionWorker.start,
       _now = now ?? DateTime.now;

  // Whisper needs enough musical context to separate a sung phrase from the
  // backing track. Two-second clips frequently returned an empty transcript.
  static const _windowSamples = 16000 * 6;

  final Duration watchdogInterval;
  final GeneratedLyricsStore store;
  final PlaybackPcmCapture _capture;
  final WhisperModelPack _models;
  final Future<RecognitionWorker> Function(WhisperModelFiles) _workerFactory;
  final DateTime Function() _now;
  final _status = StreamController<LearningStatus>.broadcast();
  final List<double> _buffer = [];
  final List<_TranscriptSection> _sections = [];
  final List<Future<void>> _pending = [];
  StreamSubscription<PcmChunk>? _audioSubscription;
  RecognitionWorker? _worker;
  TrackIdentity? _track;
  Duration _captureStart = Duration.zero;
  var _submittedSamples = 0;
  DateTime? _requestedAt;
  bool _anchored = false;
  bool _acceptResults = false;
  Timer? _captureWatchdog;
  DateTime? _lastPcmAt;
  DateTime? _lastSignalAt;
  DateTime? _listeningAt;
  DateTime? _recognitionStartedAt;
  var _generation = 0;
  Future<LyricTimeline?>? _finishing;
  Future<void>? _captureFailure;

  @override
  Stream<LearningStatus> get statuses => _status.stream;

  @override
  Future<void> start(TrackIdentity track, Duration currentPosition) async {
    await _captureFailure;
    if (_track?.cacheKey == track.cacheKey) return;
    await finish(stopCapture: true);
    if (_track != null) return;
    final generation = ++_generation;
    _track = track;
    _captureStart = currentPosition;
    _requestedAt = _now();
    _anchored = false;
    _acceptResults = true;
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
      final worker = await _workerFactory(files);
      if (generation != _generation) {
        await worker.dispose();
        return;
      }
      _worker = worker;
      _audioSubscription = _capture.chunks.listen(
        _onPcm,
        onError: (Object error) => unawaited(
          _failCapture('Audio capture stopped: ${error.toString()}'),
        ),
        onDone: () =>
            unawaited(_failCapture('The audio stream stopped. Retry capture.')),
      );
      _emit(const LearningStatus(LearningState.awaitingCapturePermission));
      await _capture.start(sourcePackage: track.sourcePackage);
      if (generation != _generation) {
        await _capture.stop();
        return;
      }
      _listeningAt = _now();
      _lastPcmAt = null;
      _lastSignalAt = null;
      _recognitionStartedAt = null;
      _captureWatchdog = Timer.periodic(watchdogInterval, (_) {
        final now = _now();
        final sinceAudio = now.difference(_lastPcmAt ?? _listeningAt!);
        final sinceSignal = now.difference(_lastSignalAt ?? _listeningAt!);
        if (sinceAudio >= const Duration(seconds: 12)) {
          unawaited(
            _failCapture(
              'No audio arrived after permission was granted. The player may block capture. Published lyrics remain available.',
            ),
          );
        } else if (sinceSignal >= const Duration(seconds: 15)) {
          unawaited(
            _failCapture(
              'Captured audio is silent. Check playback and volume; this player may block audio capture.',
            ),
          );
        } else if (_sections.isEmpty &&
            _recognitionStartedAt != null &&
            now.difference(_recognitionStartedAt!) >=
                const Duration(seconds: 45)) {
          unawaited(
            _failCapture(
              'Audio arrived, but recognition produced no usable lyrics within 45 seconds. Local AI is unavailable for this song.',
            ),
          );
        }
      });
      _emit(
        const LearningStatus(
          LearningState.listening,
          message:
              'Learning a draft for replay. The first phrase needs at least six seconds of audio.',
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

  Future<void> _failCapture(String message) => _captureFailure ??=
      _stopFailedCapture(message).whenComplete(() => _captureFailure = null);

  Future<void> _stopFailedCapture(String message) async {
    if (!_acceptResults || _finishing != null) return;
    _acceptResults = false;
    _generation++;
    _captureWatchdog?.cancel();
    _captureWatchdog = null;
    _emit(LearningStatus(LearningState.unavailable, message: message));
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _capture.stop();
    await _worker?.dispose();
    _worker = null;
    _pending.clear();
    _buffer.clear();
    _track = null;
  }

  void _onPcm(PcmChunk chunk) {
    if (chunk.sampleRate != 16000 || _worker == null || _finishing != null) {
      return;
    }
    _lastPcmAt = _now();
    if (TranscriptQuality.hasSignal(chunk.samples)) _lastSignalAt = _now();
    if (!_anchored) {
      // Anchor the FIRST captured audio, after model setup and user consent.
      final delay = _now().difference(_requestedAt!);
      final chunkDuration = Duration(
        microseconds: chunk.samples.length * 1000000 ~/ 16000,
      );
      _captureStart += delay > chunkDuration
          ? delay - chunkDuration
          : Duration.zero;
      _anchored = true;
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
    if (!TranscriptQuality.hasSignal(samples)) {
      _emit(
        const LearningStatus(
          LearningState.listening,
          message:
              'Audio is arriving, but it is silent. Check playback and volume.',
        ),
      );
      return;
    }
    _recognitionStartedAt ??= _now();
    _emit(
      const LearningStatus(
        LearningState.listening,
        message: 'Audio received · recognizing a lyric phrase…',
      ),
    );
    if (_pending.length >= 2) {
      _emit(
        const LearningStatus(
          LearningState.listening,
          message:
              'Recognition is catching up. Some audio was skipped; draft coverage is incomplete.',
        ),
      );
      return;
    }
    final job = worker
        .recognize(samples)
        .then((result) {
          if (!_acceptResults) return;
          final text = TranscriptQuality.clean(result.text);
          if (TranscriptQuality.accepts(text)) {
            _sections.add(
              _TranscriptSection(
                text,
                offset,
                duration,
                TranscriptQuality.timedWords(result, text, offset, duration),
              ),
            );
            _emit(
              LearningStatus(
                LearningState.listening,
                message:
                    'AI draft captured for replay. Words may be inaccurate.',
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
          if (!_acceptResults) return;
          unawaited(
            _failCapture(
              _friendlyLearningError(error, duringRecognition: true),
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
    _captureWatchdog?.cancel();
    _captureWatchdog = null;
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
      await Future.wait(
        List.of(_pending),
      ).timeout(const Duration(seconds: 20)).catchError((_) => <void>[]);
      _acceptResults = false;
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
      _acceptResults = false;
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
            confidence: .4,
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

  void _emit(LearningStatus value) {
    if (!_status.isClosed) {
      _status.add(
        LearningStatus(
          value.state,
          progress: value.progress,
          message: value.message,
          partialTimeline: value.partialTimeline,
          trackKey: _track?.cacheKey,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await finish(stopCapture: true);
    await _status.close();
  }
}

String _friendlyLearningError(Object error, {bool duringRecognition = false}) {
  if (error is FileSystemException) {
    return 'The model or saved lyrics could not be accessed. Check free storage and retry.';
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('selected music app')) {
    return 'The selected music app could not be captured on this device. Published lyrics remain available.';
  }
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
