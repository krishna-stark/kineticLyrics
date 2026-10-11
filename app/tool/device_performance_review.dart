// Dedicated quality entry point. Never imported by lib/main.dart and never
// used by the production build. Synthetic signals test rendering, not beat
// detection or real vocal alignment.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kinetic_lyrics/app/kinetic_lyrics_controller.dart';
import 'package:kinetic_lyrics/audio/audio_analyzer.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_provider.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/main.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_detector.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_snapshot.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_track.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    KineticLyricsApp(
      controller: KineticLyricsController(
        nowPlaying: _ReviewClock(),
        lyrics: LyricsRepository(providers: [_ReviewLyrics()]),
        audio: _ReviewAudio(),
      ),
    ),
  );
}

class _ReviewClock implements NowPlayingDetector {
  final _events = StreamController<NowPlayingSnapshot>.broadcast();
  final _watch = Stopwatch()..start();
  Timer? _timer;
  @override
  Stream<NowPlayingSnapshot> get snapshots {
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _publish(),
    );
    return _events.stream;
  }

  void _publish() {
    final elapsed = _watch.elapsedMilliseconds;
    final chapter = elapsed ~/ 30000 % 3;
    _events.add(
      NowPlayingSnapshot(
        access: NowPlayingAccess.granted,
        track: NowPlayingTrack(
          sourcePackage: '__render_quality__',
          sourceName: 'Rendering QA',
          title: [
            'QA · Intimate melody',
            'QA · Fast delivery',
            'QA · Native-script refrain',
          ][chapter],
          artist: 'Synthetic fixture · no audio',
          album: null,
          duration: const Duration(seconds: 30),
          position: Duration(milliseconds: elapsed % 30000),
          playbackSpeed: 1,
          state: PlaybackStatus.playing,
          receivedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<void> refresh() async => _publish();
  @override
  Future<void> openAccessSettings() async {}
  @override
  void dispose() {
    _timer?.cancel();
    _events.close();
  }
}

class _ReviewAudio implements AudioAnalyzer {
  final _events = StreamController<AudioFeatures>.broadcast();
  final _watch = Stopwatch()..start();
  Timer? _timer;
  @override
  Stream<AudioFeatures> get frames {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final t = _watch.elapsedMicroseconds / 1e6;
      final chapter = t ~/ 30 % 3;
      final low = math.pow(1 - (t * 2 % 1), 5).toDouble();
      final mid = math.pow(1 - (t * 3 % 1), 7).toDouble();
      final high = math.pow(1 - (t * 5 % 1), 10).toDouble();
      final energy = chapter == 0 ? .22 : .72;
      _events.add(
        AudioFeatures(
          live: true,
          energy: energy,
          rms: .1,
          bass: chapter == 0 ? .15 : low * .8,
          mid: chapter == 0 ? .5 : mid * .6,
          treble: high * .55,
          onset: chapter == 0 ? 0 : low,
          bassOnset: chapter == 0 ? 0 : low,
          midOnset: mid,
          trebleOnset: high,
          waveform: List.generate(
            64,
            (i) => math.sin(i * .22 + t) * (.35 + low * .3),
          ),
          spectrum: List.generate(
            32,
            (i) =>
                (.08 +
                        math.sin(i * .6 + t).abs() * .25 +
                        (i < 10
                                ? low
                                : i < 23
                                ? mid
                                : high) *
                            .38)
                    .clamp(0.0, 1.0),
          ),
          timestamp: _watch.elapsed,
        ),
      );
    });
    return _events.stream;
  }

  @override
  Future<void> requestAccess() async {}
  @override
  void dispose() {
    _timer?.cancel();
    _events.close();
  }
}

class _ReviewLyrics implements LyricsProvider {
  @override
  String get id => 'render-quality-fixture';
  @override
  Future<LyricTimeline?> find(TrackIdentity track) async {
    final texts = track.title.contains('Fast')
        ? [
            'Find our rhythm carry it forward',
            'Move with the music into the night',
            'Every word arrives with its own energy',
            'Hold the line and let it go',
            '',
            'Find our rhythm carry it forward',
            'Move with the music into the night',
            'Every word arrives with its own energy',
            'Hold the line and let it go',
            '',
          ]
        : track.title.contains('Native')
        ? [
            'ప్రేమ ప్రతి క్షణం నీతో',
            'కన్నుల్లో నక్షత్రాలు మెరిసే',
            'నీతో నా ప్రయాణం',
            '',
            'காதல் நிலா இதயம்',
            'కన్నుల్లో నక్షత్రాలు మెరిసే',
            'నీతో నా ప్రయాణం',
            '',
          ]
        : [
            'Love in the moonlight',
            'Stay a little closer',
            'The night belongs to us',
            '',
            'Stay a little closer',
            'The night belongs to us',
            '',
          ];
    final span = 30000 ~/ texts.length;
    return LyricTimeline(
      provider: id,
      quality: LyricsTimingQuality.wordSynced,
      lines: [
        for (var index = 0; index < texts.length; index++)
          _line(texts[index], index * span, span),
      ],
    );
  }

  LyricLine _line(String text, int start, int span) {
    final tokens = text.isEmpty ? <String>[] : text.split(' ');
    return LyricLine(
      text: text,
      start: Duration(milliseconds: start),
      end: Duration(milliseconds: start + span),
      confidence: .94,
      provenance: TimingProvenance.provider,
      words: [
        for (var i = 0; i < tokens.length; i++)
          LyricWord(
            text: tokens[i],
            start: Duration(milliseconds: start + span * i ~/ tokens.length),
            end: Duration(
              milliseconds: start + span * (i + 1) ~/ tokens.length,
            ),
            confidence: .94,
            provenance: TimingProvenance.provider,
            stress: i == 0 ? .8 : .2,
          ),
      ],
    );
  }
}
