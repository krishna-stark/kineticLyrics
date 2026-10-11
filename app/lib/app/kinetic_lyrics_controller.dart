import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_analyzer.dart';
import '../semantics/on_device_semantic_analyzer.dart';
import '../semantics/song_semantic_profile.dart';
import '../audio/audio_features.dart';
import '../audio/music_state.dart';
import '../lyrics/data/lyrics_repository.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../lyrics/domain/track_identity.dart';
import '../learning/on_device_lyrics_learner.dart';
import '../now_playing/now_playing_detector.dart';
import '../now_playing/now_playing_snapshot.dart';
import '../now_playing/now_playing_track.dart';

enum LyricsLoadState { idle, loading, ready, notFound, error }

enum SemanticAnalysisStatus { idle, analyzing, ready, fallback, error }

class KineticLyricsController extends ChangeNotifier {
  KineticLyricsController({
    required NowPlayingDetector nowPlaying,
    required LyricsRepository lyrics,
    AudioAnalyzer audio = const SilentAudioAnalyzer(),
    LyricsLearner? learner,
    LyricSemanticAnalyzer? semanticAnalyzer,
  }) : this._(nowPlaying, lyrics, audio, learner, semanticAnalyzer);

  KineticLyricsController._(
    this._nowPlaying,
    this._lyrics,
    this._audio,
    this._learner,
    this._semanticAnalyzer,
  );

  final NowPlayingDetector _nowPlaying;
  final LyricsRepository _lyrics;
  final AudioAnalyzer _audio;
  final LyricsLearner? _learner;
  final LyricSemanticAnalyzer? _semanticAnalyzer;
  SongSemanticProfile? _semanticProfile;
  SongSemanticProfile? get semanticProfile => _semanticProfile;
  SemanticAnalysisStatus semanticStatus = SemanticAnalysisStatus.idle;
  StreamSubscription<NowPlayingSnapshot>? _subscription;
  StreamSubscription<AudioFeatures>? _audioSubscription;
  StreamSubscription<LearningStatus>? _learningSubscription;
  int _lookupGeneration = 0;
  String? _loadedTrackKey;
  bool _disposed = false;
  bool _acceptLearning = true;
  final MusicStateTracker _musicTracker = MusicStateTracker();
  Duration? _learningPreviewStart;
  Duration? _frozenPreview;
  Duration? _learningPreviewEnd;
  DateTime? _learningPreviewReceivedAt;

  NowPlayingSnapshot snapshot = NowPlayingSnapshot.checking();
  LyricsLoadState lyricsState = LyricsLoadState.idle;
  LyricTimeline? timeline;
  AudioFeatures audioFeatures = AudioFeatures.silent;
  bool audioAvailable = false;
  bool audioSignal = false;
  Duration? _lastAudioSignal;
  MusicState musicState = MusicState.silent;
  LearningStatus learningStatus = const LearningStatus(LearningState.idle);

  Duration? get learningPreviewPosition {
    final start = _learningPreviewStart;
    final end = _learningPreviewEnd;
    final receivedAt = _learningPreviewReceivedAt;
    if (start == null || end == null || receivedAt == null) return null;
    if (snapshot.track?.isAdvancing != true) return _frozenPreview ?? start;
    final elapsed = DateTime.now().difference(receivedAt);
    if (elapsed > end - start + const Duration(seconds: 3)) return null;
    final preview = start + elapsed;
    final latest = end - const Duration(milliseconds: 80);
    return preview > latest ? latest : preview;
  }

  void initialize() {
    _subscription ??= _nowPlaying.snapshots.listen(
      _onNowPlaying,
      onError: (_) {
        snapshot = const NowPlayingSnapshot(
          access: NowPlayingAccess.error,
          message: 'The media detector stopped unexpectedly.',
        );
        lyricsState = LyricsLoadState.idle;
        timeline = null;
        _lookupGeneration++;
        _semanticProfile = null;
        semanticStatus = SemanticAnalysisStatus.idle;
        notifyListeners();
      },
    );
    _audioSubscription ??= _audio.frames.listen((frame) {
      final oldSignal = audioSignal;
      final availabilityChanged = audioAvailable != frame.live;
      audioAvailable = frame.live;
      if (frame.live &&
          (frame.rms > .001 || frame.bass > .005 || frame.mid > .005)) {
        _lastAudioSignal = frame.timestamp;
        audioSignal = true;
      } else if (!frame.live ||
          _lastAudioSignal == null ||
          frame.timestamp - _lastAudioSignal! > const Duration(seconds: 2)) {
        audioSignal = false;
      }
      musicState = snapshot.track?.isAdvancing == true
          ? _musicTracker.update(frame)
          : MusicState.silent;
      audioFeatures = musicState.features;
      if ((availabilityChanged || oldSignal != audioSignal) && !_disposed) {
        notifyListeners();
      }
    });
    _learningSubscription ??= _learner?.statuses.listen((status) {
      if (!_acceptLearning || _disposed) return;
      learningStatus = status;
      if (status.partialTimeline != null) {
        timeline = status.partialTimeline;
        final lines = status.partialTimeline!.lines;
        if (lines.isNotEmpty) {
          _frozenPreview = null;
          _learningPreviewStart = lines.last.start;
          _learningPreviewEnd = lines.last.end;
          _learningPreviewReceivedAt = DateTime.now();
        }
        lyricsState = LyricsLoadState.ready;
      }
      notifyListeners();
      if (status.state == LearningState.learned) {
        unawaited(retryLyrics());
      }
    });
  }

  Future<void> openAccessSettings() => _nowPlaying.openAccessSettings();

  Future<void> refresh() => _nowPlaying.refresh();

  Future<void> retryLyrics() async {
    final track = snapshot.track;
    if (track == null) return;
    final identity = TrackIdentity.fromNowPlaying(track);
    _lyrics.invalidate(identity);
    _loadedTrackKey = null;
    await _loadLyrics(identity);
  }

  void _onNowPlaying(NowPlayingSnapshot value) {
    final previousTrack = snapshot.track;
    final preview = learningPreviewPosition;
    final wasAdvancing = snapshot.track?.isAdvancing == true;
    snapshot = value;
    if (wasAdvancing && value.track?.isAdvancing != true) {
      _frozenPreview = preview;
    }
    if (!wasAdvancing &&
        value.track?.isAdvancing == true &&
        _frozenPreview != null) {
      _learningPreviewStart = _frozenPreview;
      _learningPreviewReceivedAt = DateTime.now();
      _frozenPreview = null;
    }
    final track = value.track;
    if (track == null) {
      _acceptLearning = false;
      learningStatus = const LearningStatus(LearningState.idle);
      unawaited(_learner?.finish(stopCapture: true));
      _musicTracker.reset();
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
      _loadedTrackKey = null;
      timeline = null;
      _semanticProfile = null;
      semanticStatus = SemanticAnalysisStatus.idle;
      _frozenPreview = null;
      _learningPreviewStart = null;
      _learningPreviewEnd = null;
      _learningPreviewReceivedAt = null;
      lyricsState = LyricsLoadState.idle;
      _lookupGeneration++;
      notifyListeners();
      return;
    }

    final identity = TrackIdentity.fromNowPlaying(track);
    final changed = identity.cacheKey != _loadedTrackKey;
    final sought =
        !changed &&
        previousTrack != null &&
        (track.state == PlaybackStatus.seeking ||
            (track.position - previousTrack.positionAt(DateTime.now()))
                    .inMilliseconds
                    .abs() >
                1500);
    if (sought) {
      _frozenPreview = null;
      _learningPreviewStart = null;
      _learningPreviewEnd = null;
      _learningPreviewReceivedAt = null;
      if (learningStatus.state == LearningState.listening) {
        unawaited(cancelLearningLyrics());
      }
    }
    if (changed) {
      if (_loadedTrackKey != null) _acceptLearning = false;
      learningStatus = const LearningStatus(LearningState.idle);
      unawaited(_learner?.finish(stopCapture: true));
      _musicTracker.reset();
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
    }
    if (!track.isAdvancing) {
      if (learningStatus.state == LearningState.listening) {
        unawaited(cancelLearningLyrics());
      }
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
    }

    if (identity.cacheKey != _loadedTrackKey) {
      _frozenPreview = null;
      _learningPreviewStart = null;
      _learningPreviewEnd = null;
      _learningPreviewReceivedAt = null;
    }
    notifyListeners();
    if (identity.cacheKey != _loadedTrackKey) {
      _loadLyrics(identity);
    }
  }

  Future<void> _loadLyrics(TrackIdentity identity) async {
    _loadedTrackKey = identity.cacheKey;
    final generation = ++_lookupGeneration;
    timeline = null;
    _semanticProfile = null;
    semanticStatus = SemanticAnalysisStatus.idle;
    lyricsState = LyricsLoadState.loading;
    notifyListeners();

    LyricTimeline? result;
    try {
      result = await _lyrics.find(identity);
    } catch (_) {
      if (!_disposed && generation == _lookupGeneration) {
        lyricsState = LyricsLoadState.error;
        notifyListeners();
      }
      return;
    }
    if (_disposed ||
        generation != _lookupGeneration ||
        identity.cacheKey != _loadedTrackKey) {
      return;
    }
    timeline = result;
    lyricsState = result == null
        ? LyricsLoadState.notFound
        : LyricsLoadState.ready;
    notifyListeners();
    if (result != null && _semanticAnalyzer != null) {
      unawaited(_analyzeSemantics(identity, result, generation));
    }
  }

  Future<void> _analyzeSemantics(
    TrackIdentity identity,
    LyricTimeline lyrics,
    int generation,
  ) async {
    semanticStatus = SemanticAnalysisStatus.analyzing;
    notifyListeners();
    try {
      final profile = await _semanticAnalyzer!.analyze(identity, lyrics);
      if (_disposed ||
          generation != _lookupGeneration ||
          identity.cacheKey != _loadedTrackKey ||
          profile.trackKey != identity.cacheKey) {
        return;
      }
      _semanticProfile = profile;
      semanticStatus = profile.aiGenerated
          ? SemanticAnalysisStatus.ready
          : SemanticAnalysisStatus.fallback;
    } catch (_) {
      if (_disposed ||
          generation != _lookupGeneration ||
          identity.cacheKey != _loadedTrackKey) {
        return;
      }
      semanticStatus = SemanticAnalysisStatus.error;
    }
    notifyListeners();
  }

  Future<void> startLearningLyrics() async {
    final track = snapshot.track;
    if (track == null || !track.isAdvancing || _learner == null) return;
    final identity = TrackIdentity.fromNowPlaying(track);
    _acceptLearning = true;
    await _learner.start(identity, track.positionAt(DateTime.now()));
  }

  Future<void> cancelLearningLyrics() async {
    _acceptLearning = false;
    learningStatus = const LearningStatus(LearningState.idle);
    notifyListeners();
    await _learner?.finish(stopCapture: true);
  }

  Future<void> enableAudioReaction() async {
    try {
      await _audio.requestAccess();
    } catch (_) {
      // Timestamp-driven visuals remain available after permission denial.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _lookupGeneration++;
    _subscription?.cancel();
    _audioSubscription?.cancel();
    _learningSubscription?.cancel();
    unawaited(_learner?.dispose());
    _semanticAnalyzer?.dispose();
    _audio.dispose();
    _nowPlaying.dispose();
    super.dispose();
  }
}
