import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/learning/generated_lyrics_store.dart';
import 'package:kinetic_lyrics/learning/on_device_lyrics_learner.dart';
import 'package:kinetic_lyrics/learning/playback_pcm_capture.dart';
import 'package:kinetic_lyrics/learning/whisper_model_pack.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';

void main() {
  test(
    'cancelling model preflight never starts capture after download resolves',
    () async {
      final models = PendingModels();
      final capture = FakeCapture();
      final learner = OnDeviceLyricsLearner(
        store: GeneratedLyricsStore(),
        models: models,
        capture: capture,
      );
      final states = <LearningState>[];
      final subscription = learner.statuses.listen((s) => states.add(s.state));
      final start = learner.start(
        const TrackIdentity(
          title: 'Song',
          album: null,
          duration: null,
          artist: 'Artist',
          sourcePackage: 'player',
        ),
        Duration.zero,
      );
      await Future<void>.delayed(Duration.zero);
      expect(states, contains(LearningState.preparingModel));
      await learner.finish(stopCapture: true);
      models.result.complete(
        const WhisperModelFiles(
          encoder: 'unused',
          decoder: 'unused',
          tokens: 'unused',
        ),
      );
      await start;
      expect(capture.starts, 0);
      expect(models.cancellations, greaterThanOrEqualTo(1));
      expect(states, isNot(contains(LearningState.listening)));
      await learner.dispose();
      await subscription.cancel();
    },
  );
}

class PendingModels extends WhisperModelPack {
  final result = Completer<WhisperModelFiles>();
  int cancellations = 0;
  @override
  Future<WhisperModelFiles> ensureInstalled({
    void Function(double)? onProgress,
  }) => result.future;
  @override
  void cancel() {
    cancellations++;
  }
}

class FakeCapture extends PlaybackPcmCapture {
  int starts = 0;
  @override
  Stream<PcmChunk> get chunks => const Stream.empty();
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> stop() async {}
}
