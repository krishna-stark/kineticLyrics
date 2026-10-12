import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/main.dart';
import 'package:kinetic_lyrics/app/kinetic_lyrics_controller.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_provider.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_detector.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_snapshot.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_track.dart';
import 'package:kinetic_lyrics/visuals/music_surface.dart';

void main() {
  testWidgets('first launch gives a useful state instead of a blank shell', (
    tester,
  ) async {
    _phoneViewport(tester);
    final detector = TestDetector();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: []),
    );
    await tester.pumpWidget(KineticLyricsApp(controller: controller));
    expect(find.text('Welcome to Kinetic Lyrics'), findsOneWidget);
    detector.add(
      const NowPlayingSnapshot(access: NowPlayingAccess.unsupported),
    );
    await tester.pump();
    expect(find.text('Music detection needs Android'), findsOneWidget);
    expect(find.byType(MusicSurface), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await detector.close();
  });

  testWidgets('ready lyrics with hidden controls retain a full-width canvas', (
    tester,
  ) async {
    _phoneViewport(tester);
    final detector = TestDetector();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: [TestLyrics()]),
    );
    await tester.pumpWidget(KineticLyricsApp(controller: controller));
    detector.add(
      NowPlayingSnapshot(
        access: NowPlayingAccess.granted,
        track: TestDetector.track(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.lyricsState, LyricsLoadState.ready);
    expect(tester.getSize(find.byType(MusicSurface)), const Size(360, 780));
    expect(find.text('Tap anywhere to hide controls'), findsNothing);
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(find.text('Tap anywhere to hide controls'), findsOneWidget);
    controller.audioAvailable = true;
    controller.audioSignal = false;
    detector.add(
      NowPlayingSnapshot(
        access: NowPlayingAccess.granted,
        track: TestDetector.track(),
      ),
    );
    await tester.pump();
    final recovery = find.ancestor(
      of: find.text('No audio signal · check volume'),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(recovery).onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MusicSurface>(find.byType(MusicSurface)).visualizerOpacity,
      closeTo(.12, .001),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MusicSurface>(find.byType(MusicSurface)).visualizerOpacity,
      1,
    );

    expect(find.text('Tap anywhere to hide controls'), findsNothing);
    expect(tester.getSize(find.byType(MusicSurface)), const Size(360, 780));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await detector.close();
  });

  testWidgets('notification explanation remains usable at large text size', (
    tester,
  ) async {
    _phoneViewport(tester, scale: 2.5);
    final detector = TestDetector();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: []),
    );
    await tester.pumpWidget(KineticLyricsApp(controller: controller));
    detector.add(const NowPlayingSnapshot(access: NowPlayingAccess.denied));
    await tester.pump();
    expect(find.text('Open Notification Access'), findsOneWidget);
    await tester.ensureVisible(find.text('Open Notification Access'));
    await tester.tap(find.text('Open Notification Access'));
    expect(detector.settingsOpened, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await detector.close();
  });

  testWidgets('missing lyrics keep one surface and require AI consent', (
    tester,
  ) async {
    _phoneViewport(tester);
    final detector = TestDetector();
    final controller = KineticLyricsController(
      nowPlaying: detector,
      lyrics: LyricsRepository(providers: []),
    );
    await tester.pumpWidget(KineticLyricsApp(controller: controller));
    detector.add(
      NowPlayingSnapshot(
        access: NowPlayingAccess.granted,
        track: TestDetector.track(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MusicSurface), findsOneWidget);
    expect(
      find.text('Lyrics unavailable · instrumental experience'),
      findsNothing,
    );
    await tester.tapAt(const Offset(180, 400));
    await tester.pump();
    expect(
      find.text('Lyrics unavailable · instrumental experience'),
      findsOneWidget,
    );
    await tester.tap(find.text('Learn lyrics on device'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Learn lyrics on this phone'), findsOneWidget);
    expect(
      find.textContaining('Captured audio is never uploaded'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Keep the instrumental experience'));
    await tester.tap(find.text('Keep the instrumental experience'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Learn lyrics on this phone'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await detector.close();
  });
}

class TestDetector implements NowPlayingDetector {
  final _stream = StreamController<NowPlayingSnapshot>.broadcast();
  int settingsOpened = 0;
  void add(NowPlayingSnapshot snapshot) => _stream.add(snapshot);
  Future<void> close() => _stream.close();
  static NowPlayingTrack track({
    PlaybackStatus state = PlaybackStatus.playing,
    String title = 'Song',
  }) => NowPlayingTrack(
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
  );
  @override
  Stream<NowPlayingSnapshot> get snapshots => _stream.stream;
  @override
  Future<void> openAccessSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> refresh() async {}
  @override
  void dispose() {}
}

void _phoneViewport(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

class TestLyrics implements LyricsProvider {
  @override
  String get id => 'fixture';
  @override
  Future<LyricTimeline?> find(TrackIdentity track) async => const LyricTimeline(
    provider: 'fixture',
    quality: LyricsTimingQuality.lineSynced,
    lines: [
      LyricLine(
        text: 'Words stay together',
        start: Duration.zero,
        end: Duration(seconds: 30),
      ),
    ],
  );
}
