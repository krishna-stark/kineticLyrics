import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/semantics/on_device_semantic_analyzer.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';
import 'package:kinetic_lyrics/audio/audio_analyzer.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/app/kinetic_lyrics_controller.dart';
import 'package:kinetic_lyrics/learning/on_device_lyrics_learner.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_provider.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_detector.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_snapshot.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_track.dart';

void main() {
  test(
    'semantic AI resolves asynchronously and ignores the previous track',
    () async {
      final detector = _FakeNowPlayingDetector();
      final provider = _QueuedProvider();
      final semantics = _QueuedSemantics();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: [provider]),
        semanticAnalyzer: semantics,
      )..initialize();
      detector.add(_snapshot('First'));
      await _settle();
      provider.requests[0].complete(_timeline('first lyric'));
      await _settle();
      expect(controller.lyricsState, LyricsLoadState.ready);
      expect(controller.semanticStatus, SemanticAnalysisStatus.analyzing);
      detector.add(_snapshot('Second'));
      await _settle();
      expect(controller.semanticProfile, isNull);
      provider.requests[1].complete(_timeline('second lyric'));
      await _settle();
      semantics.requests[0].complete(semantics.profile(0));
      await _settle();
      expect(controller.semanticProfile, isNull);
      expect(controller.semanticStatus, SemanticAnalysisStatus.analyzing);
      semantics.requests[1].complete(semantics.profile(1));
      await _settle();
      expect(
        controller.semanticProfile!.trackKey,
        semantics.tracks[1].cacheKey,
      );
      expect(controller.semanticStatus, SemanticAnalysisStatus.ready);
      controller.dispose();
      expect(semantics.disposed, isTrue);
      await detector.close();
    },
  );

  test('late semantic AI cannot notify after controller disposal', () async {
    final detector = _FakeNowPlayingDetector();
    final provider = _QueuedProvider();
    final semantics = _QueuedSemantics();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: [provider]),
      semanticAnalyzer: semantics,
    )..initialize();
    detector.add(_snapshot('Song'));
    await _settle();
    provider.requests[0].complete(_timeline('lyric'));
    await _settle();
    controller.dispose();
    semantics.requests.single.complete(semantics.profile(0));
    await _settle();
    expect(controller.semanticProfile, isNull);
    await detector.close();
  });

  test(
    'failed semantic AI preserves ready lyrics with explicit status',
    () async {
      final detector = _FakeNowPlayingDetector();
      final provider = _QueuedProvider();
      final semantics = _QueuedSemantics();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: [provider]),
        semanticAnalyzer: semantics,
      )..initialize();
      detector.add(_snapshot('Song'));
      await _settle();
      provider.requests[0].complete(_timeline('lyric'));
      await _settle();
      semantics.requests.single.completeError(
        StateError('inference unavailable'),
      );
      await _settle();
      expect(controller.lyricsState, LyricsLoadState.ready);
      expect(controller.semanticStatus, SemanticAnalysisStatus.error);
      controller.dispose();
      await detector.close();
    },
  );

  test(
    'audio status changes notify controls without rebuilding on every FFT frame',
    () async {
      final detector = _FakeNowPlayingDetector();
      final audio = _TestAudio();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: []),
        audio: audio,
      )..initialize();
      var changes = 0;
      controller.addListener(() => changes++);
      audio.events.add(const AudioFeatures(live: true, bass: .5));
      await _settle();
      expect(controller.audioAvailable, isTrue);
      expect(changes, 1);
      audio.events.add(const AudioFeatures(live: true, bass: .8));
      await _settle();
      expect(changes, 1);
      audio.events.add(AudioFeatures.silent);
      await _settle();
      expect(controller.audioAvailable, isFalse);
      expect(changes, 2);
      controller.dispose();
      await audio.events.close();
      await detector.close();
    },
  );
  test(
    'missing lyrics require explicit consent before capture starts',
    () async {
      final detector = _FakeNowPlayingDetector();
      final learner = _FakeLearner();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: const [_MissingProvider()]),
        learner: learner,
      )..initialize();

      detector.add(
        NowPlayingSnapshot(
          access: NowPlayingAccess.granted,
          track: NowPlayingTrack(
            sourcePackage: 'player',
            sourceName: 'Player',
            title: 'Missing Song',
            artist: 'Artist',
            album: null,
            duration: const Duration(minutes: 3),
            position: const Duration(seconds: 8),
            playbackSpeed: 1,
            state: PlaybackStatus.playing,
            receivedAt: DateTime.now(),
          ),
        ),
      );
      await _settle();

      expect(controller.lyricsState, LyricsLoadState.notFound);
      expect(learner.starts, 0);
      await controller.startLearningLyrics();
      expect(learner.starts, 1);
      controller.dispose();
      await detector.close();
    },
  );

  test(
    'a paused track change clears old lyrics and loads the new track',
    () async {
      final detector = _FakeNowPlayingDetector();
      final provider = _QueuedProvider();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: [provider]),
      )..initialize();
      detector.add(_snapshot('First'));
      await _settle();
      provider.requests[0].complete(_timeline('first lyric'));
      await _settle();
      expect(controller.timeline!.lines.single.text, 'first lyric');
      detector.add(_snapshot('Second', state: PlaybackStatus.paused));
      await _settle();
      expect(controller.timeline, isNull);
      expect(controller.lyricsState, LyricsLoadState.loading);
      provider.requests[1].complete(_timeline('second lyric'));
      await _settle();
      expect(controller.timeline!.lines.single.text, 'second lyric');
      controller.dispose();
      await detector.close();
    },
  );

  test(
    'late lookups cannot restore an old track or notify after disposal',
    () async {
      final detector = _FakeNowPlayingDetector();
      final provider = _QueuedProvider();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: [provider]),
      )..initialize();
      detector.add(_snapshot('First'));
      await _settle();
      detector.add(_snapshot('Second'));
      await _settle();
      provider.requests[0].complete(_timeline('old'));
      await _settle();
      expect(controller.timeline, isNull);
      controller.dispose();
      provider.requests[1].complete(_timeline('new'));
      await _settle();
      await detector.close();
    },
  );

  test('lookup failures have a distinct retryable state', () async {
    final detector = _FakeNowPlayingDetector();
    final provider = _QueuedProvider();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: [provider]),
    )..initialize();
    detector.add(_snapshot('Song'));
    await _settle();
    provider.requests[0].completeError(StateError('raw private server detail'));
    await _settle();
    expect(controller.lyricsState, LyricsLoadState.error);
    controller.dispose();
    await detector.close();
  });

  test('partial on-device AI lyrics immediately become available', () async {
    final detector = _FakeNowPlayingDetector();
    final learner = _FakeLearner();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: const [_MissingProvider()]),
      learner: learner,
    )..initialize();

    detector.add(
      NowPlayingSnapshot(
        access: NowPlayingAccess.granted,
        track: NowPlayingTrack(
          sourcePackage: 'player',
          sourceName: 'Player',
          title: 'Recovered Song',
          artist: 'Artist',
          album: null,
          duration: const Duration(minutes: 3),
          position: const Duration(seconds: 8),
          playbackSpeed: 1,
          state: PlaybackStatus.playing,
          receivedAt: DateTime.now(),
        ),
      ),
    );
    await _settle();

    const partial = LyricTimeline(
      provider: 'on-device-ai',
      quality: LyricsTimingQuality.estimated,
      lines: [
        LyricLine(
          text: 'a recovered lyric',
          start: Duration(seconds: 7),
          end: Duration(seconds: 10),
        ),
      ],
    );
    learner.emit(
      const LearningStatus(LearningState.listening, partialTimeline: partial),
    );
    await _settle();

    expect(controller.lyricsState, LyricsLoadState.ready);
    expect(controller.timeline, partial);
    expect(
      controller.learningPreviewPosition,
      isNotNull,
      reason: 'Freshly transcribed lyrics must remain visible despite ASR lag.',
    );
    expect(
      controller.learningPreviewPosition!,
      greaterThanOrEqualTo(partial.lines.last.start),
    );
    controller.dispose();
    await detector.close();
  });
}

class _TestAudio implements AudioAnalyzer {
  final events = StreamController<AudioFeatures>();
  @override
  Stream<AudioFeatures> get frames => events.stream;
  @override
  Future<void> requestAccess() async {}
  @override
  void dispose() {}
}

Future<void> _settle() async {
  for (var index = 0; index < 4; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeNowPlayingDetector implements NowPlayingDetector {
  final _controller = StreamController<NowPlayingSnapshot>.broadcast();

  @override
  Stream<NowPlayingSnapshot> get snapshots => _controller.stream;

  void add(NowPlayingSnapshot value) => _controller.add(value);
  Future<void> close() => _controller.close();

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<void> refresh() async {}

  @override
  void dispose() {}
}

class _MissingProvider implements LyricsProvider {
  const _MissingProvider();

  @override
  String get id => 'missing';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async => null;
}

class _FakeLearner implements LyricsLearner {
  final _statuses = StreamController<LearningStatus>.broadcast();
  int starts = 0;

  void emit(LearningStatus status) => _statuses.add(status);

  @override
  Stream<LearningStatus> get statuses => _statuses.stream;

  @override
  Future<void> start(TrackIdentity track, Duration currentPosition) async {
    starts++;
  }

  @override
  Future<LyricTimeline?> finish({bool stopCapture = false}) async => null;

  @override
  Future<void> dispose() => _statuses.close();
}

NowPlayingSnapshot _snapshot(
  String title, {
  PlaybackStatus state = PlaybackStatus.playing,
}) => NowPlayingSnapshot(
  access: NowPlayingAccess.granted,
  track: NowPlayingTrack(
    sourcePackage: 'player',
    sourceName: 'Player',
    title: title,
    artist: 'Artist',
    album: null,
    duration: const Duration(minutes: 3),
    position: const Duration(seconds: 8),
    playbackSpeed: 1,
    state: state,
    receivedAt: DateTime.now(),
  ),
);
LyricTimeline _timeline(String text) => LyricTimeline(
  provider: 'test',
  quality: LyricsTimingQuality.lineSynced,
  lines: [
    LyricLine(
      text: text,
      start: Duration.zero,
      end: const Duration(seconds: 20),
    ),
  ],
);

class _QueuedProvider implements LyricsProvider {
  final requests = <Completer<LyricTimeline?>>[];
  @override
  String get id => 'queued';
  @override
  Future<LyricTimeline?> find(TrackIdentity track) {
    final request = Completer<LyricTimeline?>();
    requests.add(request);
    return request.future;
  }
}

class _QueuedSemantics implements LyricSemanticAnalyzer {
  final requests = <Completer<SongSemanticProfile>>[];
  final tracks = <TrackIdentity>[];
  bool disposed = false;
  @override
  Future<SongSemanticProfile> analyze(
    TrackIdentity track,
    LyricTimeline timeline,
  ) {
    tracks.add(track);
    final request = Completer<SongSemanticProfile>();
    requests.add(request);
    return request.future;
  }

  SongSemanticProfile profile(int index) => SongSemanticProfile(
    trackKey: tracks[index].cacheKey,
    aiGenerated: true,
    analysisMilliseconds: 1,
    lines: const {
      0: LineSemanticProfile(
        lineIndex: 0,
        motionPath: SemanticMotionPath.rise,
        motionConfidence: .9,
      ),
    },
  );
  @override
  void dispose() {
    disposed = true;
  }
}
