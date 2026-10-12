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
import '../now_playing/now_playing_detector.dart';
import '../now_playing/now_playing_snapshot.dart';

enum LyricsLoadState { idle, loading, ready, notFound, error }

enum SemanticAnalysisStatus { idle, analyzing, ready, fallback, error }

class KineticLyricsController extends ChangeNotifier {
  KineticLyricsController({
    required NowPlayingDetector nowPlaying,
    required LyricsRepository lyrics,
    AudioAnalyzer audio = const SilentAudioAnalyzer(),
    LyricSemanticAnalyzer? semanticAnalyzer,
  }) : this._(nowPlaying, lyrics, audio, semanticAnalyzer);

  KineticLyricsController._(
    this._nowPlaying,
    this._lyrics,
    this._audio,
    this._semanticAnalyzer,
  );

  final NowPlayingDetector _nowPlaying;
  final LyricsRepository _lyrics;
  final AudioAnalyzer _audio;
  final LyricSemanticAnalyzer? _semanticAnalyzer;
  SongSemanticProfile? _semanticProfile;
  SongSemanticProfile? get semanticProfile => _semanticProfile;
  SemanticAnalysisStatus semanticStatus = SemanticAnalysisStatus.idle;
  StreamSubscription<NowPlayingSnapshot>? _subscription;
  StreamSubscription<AudioFeatures>? _audioSubscription;
  int _lookupGeneration = 0;
  String? _loadedTrackKey;
  bool _disposed = false;
  final MusicStateTracker _musicTracker = MusicStateTracker();

  NowPlayingSnapshot snapshot = NowPlayingSnapshot.checking();
  LyricsLoadState lyricsState = LyricsLoadState.idle;
  LyricTimeline? timeline;
  AudioFeatures audioFeatures = AudioFeatures.silent;
  bool audioAvailable = false;
  bool audioSignal = false;
  Duration? _lastAudioSignal;
  MusicState musicState = MusicState.silent;
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
    snapshot = value;
    final track = value.track;
    if (track == null) {
      _musicTracker.reset();
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
      _loadedTrackKey = null;
      timeline = null;
      _semanticProfile = null;
      semanticStatus = SemanticAnalysisStatus.idle;
      lyricsState = LyricsLoadState.idle;
      _lookupGeneration++;
      notifyListeners();
      return;
    }

    final identity = TrackIdentity.fromNowPlaying(track);
    final changed = identity.cacheKey != _loadedTrackKey;
    if (changed) {
      _musicTracker.reset();
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
    }
    if (!track.isAdvancing) {
      musicState = MusicState.silent;
      audioFeatures = AudioFeatures.silent;
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
          !identical(timeline, lyrics) ||
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
          identity.cacheKey != _loadedTrackKey ||
          !identical(timeline, lyrics)) {
        return;
      }
      semanticStatus = SemanticAnalysisStatus.error;
    }
    notifyListeners();
  }

  bool get transportAvailable => _nowPlaying is PlaybackTransport;
  Future<void> controlPlayback(String action, {Duration? position}) async {
    final track = snapshot.track;
    final transport = _nowPlaying;
    if (track == null || transport is! PlaybackTransport) {
      throw StateError('Playback control is unavailable');
    }
    if (!await (transport as PlaybackTransport).transport(
      action,
      sourcePackage: track.sourcePackage,
      title: track.title,
      positionMs: position?.inMilliseconds,
    )) {
      throw StateError('The music player did not accept this action');
    }
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
    _semanticAnalyzer?.dispose();
    _audio.dispose();
    _nowPlaying.dispose();
    super.dispose();
  }
}
