import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/learning/generated_lyrics_store.dart';
import 'package:kinetic_lyrics/learning/on_device_lyrics_learner.dart';
import 'package:kinetic_lyrics/learning/on_device_recognition_worker.dart';
import 'package:kinetic_lyrics/learning/playback_pcm_capture.dart';
import 'package:kinetic_lyrics/learning/whisper_model_pack.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';

const track = TrackIdentity(
  title: 'Song',
  artist: 'Artist',
  album: null,
  duration: Duration(minutes: 3),
  sourcePackage: 'player',
);
Future<void> settle() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'capture anchors after consent and preserves silent audio gaps',
    () async {
      var now = DateTime(2026);
      final capture = TestCapture();
      final worker = TestWorker();
      final store = TestStore();
      final learner = OnDeviceLyricsLearner(
        store: store,
        capture: capture,
        models: TestModels(),
        workerFactory: (_) async => worker,
        now: () => now,
      );
      final statuses = <LearningStatus>[];
      final subscription = learner.statuses.listen(statuses.add);
      await learner.start(track, const Duration(seconds: 10));
      now = now.add(const Duration(seconds: 25));
      capture.emit(silent: true);
      await settle();
      expect(worker.jobs, isEmpty);
      now = now.add(const Duration(seconds: 6));
      capture.emit();
      await settle();
      worker.jobs.single.complete(
        const RecognitionResult(text: 'ప్రేమ నీతో', tokens: [], timestamps: []),
      );
      await settle();
      final partial = statuses.last.partialTimeline!;
      expect(partial.lines.first.start, const Duration(seconds: 35));
      expect(partial.lines.last.end, const Duration(seconds: 41));
      expect(partial.lines.first.confidence, lessThan(.7));
      await learner.finish(stopCapture: true);
      expect(store.saved?.lines.first.start, const Duration(seconds: 35));
      await learner.dispose();
      await subscription.cancel();
      await capture.events.close();
    },
  );
  test(
    'recognition backlog is bounded without compressing skipped time',
    () async {
      var now = DateTime(2026);
      final capture = TestCapture();
      final worker = TestWorker();
      final learner = OnDeviceLyricsLearner(
        store: TestStore(),
        capture: capture,
        models: TestModels(),
        workerFactory: (_) async => worker,
        now: () => now,
      );
      final statuses = <LearningStatus>[];
      final subscription = learner.statuses.listen(statuses.add);
      await learner.start(track, Duration.zero);
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 6));
        capture.emit();
        await settle();
      }
      expect(worker.jobs, hasLength(2));
      expect(statuses.last.message, contains('incomplete'));
      worker.jobs[0].complete(
        const RecognitionResult(
          text: 'first phrase',
          tokens: [],
          timestamps: [],
        ),
      );
      await settle();
      now = now.add(const Duration(seconds: 6));
      capture.emit();
      await settle();
      expect(worker.jobs, hasLength(3));
      worker.jobs[1].complete(
        const RecognitionResult(
          text: 'second phrase',
          tokens: [],
          timestamps: [],
        ),
      );
      worker.jobs[2].complete(
        const RecognitionResult(
          text: 'fourth phrase',
          tokens: [],
          timestamps: [],
        ),
      );
      await settle();
      final partial = statuses.last.partialTimeline!;
      expect(partial.lines.last.start, const Duration(seconds: 18));
      expect(partial.lines.last.end, const Duration(seconds: 24));
      await learner.dispose();
      await subscription.cancel();
      await capture.events.close();
    },
  );
}

class TestCapture extends PlaybackPcmCapture {
  final events = StreamController<PcmChunk>();
  @override
  Stream<PcmChunk> get chunks => events.stream;
  void emit({bool silent = false}) => events.add(
    PcmChunk(
      samples: Float32List.fromList(List.filled(16000 * 6, silent ? 0 : .08)),
      sampleRate: 16000,
    ),
  );
  @override
  Future<void> start({String? sourcePackage}) async {}
  @override
  Future<void> stop() async {}
}

class TestModels extends WhisperModelPack {
  @override
  Future<WhisperModelFiles> ensureInstalled({
    void Function(double)? onProgress,
  }) async => const WhisperModelFiles(
    encoder: 'unused',
    decoder: 'unused',
    tokens: 'unused',
  );
}

class TestWorker implements RecognitionWorker {
  final jobs = <Completer<RecognitionResult>>[];
  @override
  Future<RecognitionResult> recognize(Float32List samples) {
    final job = Completer<RecognitionResult>();
    jobs.add(job);
    return job.future;
  }

  @override
  Future<void> dispose() async {}
}

class TestStore extends GeneratedLyricsStore {
  LyricTimeline? saved;
  @override
  Future<void> save(TrackIdentity track, LyricTimeline timeline) async {
    saved = timeline;
  }
}
