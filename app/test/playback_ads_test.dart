import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/main.dart';
import 'package:kinetic_lyrics/ads/song_ads.dart';
import 'package:kinetic_lyrics/app/kinetic_lyrics_controller.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_detector.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_snapshot.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_track.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';
import 'widget_test.dart' show TestDetector;

NowPlayingTrack song(
  DateTime time,
  int position, {
  String title = 'Midnight melody',
  PlaybackStatus state = PlaybackStatus.playing,
}) => NowPlayingTrack(
  sourcePackage: 'player',
  sourceName: 'Music player',
  title: title,
  artist: 'An artist',
  album: 'An album',
  duration: const Duration(seconds: 30),
  position: Duration(seconds: position),
  playbackSpeed: 1,
  state: state,
  receivedAt: time,
  playbackActions: 4 | 2 | 16 | 32 | 256,
);

class TransportDetector extends TestDetector implements PlaybackTransport {
  final commands = <String>[];
  int? seekPosition;
  @override
  Future<bool> transport(
    String action, {
    required String sourcePackage,
    required String title,
    int? positionMs,
  }) async {
    commands.add(action);
    seekPosition = positionMs;
    return true;
  }
}

void main() {
  test('five completed songs, not skips or seeks, make an ad due', () {
    final cadence = SongAdCadence();
    var time = DateTime(2026);
    for (var i = 0; i < 5; i++) {
      for (var second = 0; second <= 30; second++) {
        cadence.observe(song(time, second, title: 'Song $i'), time);
        time = time.add(const Duration(seconds: 1));
      }
    }
    expect(cadence.completed, 5);
    expect(cadence.due, true);
    cadence.observe(song(time, 30, title: 'Song 4'), time);
    expect(cadence.completed, 5);
    cadence.consumed();
    expect(cadence.due, false);
    for (var i = 0; i < 8; i++) {
      cadence.observe(song(time, 0, title: 'Skip $i'), time);
      time = time.add(const Duration(seconds: 1));
      cadence.observe(song(time, 29, title: 'Skip $i'), time);
    }
    expect(cadence.completed, 0);
  });
  test('a long pause and a seek to the end do not count listening', () {
    final c = SongAdCadence();
    var now = DateTime(2026);
    c.observe(song(now, 0), now);
    now = now.add(const Duration(minutes: 1));
    c.observe(song(now, 29, state: PlaybackStatus.paused), now);
    expect(c.completed, 0);
  });
  test('all bundled contextual emoji art decodes once', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ContextAssetStore.prepareEmojiArt();
    expect(ContextAssetStore.emojiIds.length, greaterThanOrEqualTo(40));
    expect(
      ContextAssetStore.emojiIds,
      containsAll(['rose', 'guitar', 'dancer', 'moon', 'umbrella']),
    );
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'controls seek and swipe to settings; paused info at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.runAsync(() async {
          for (final name in ['Roboto', 'SpaceGrotesk']) {
            await (FontLoader(name)
                  ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk.ttf')))
                .load();
          }
          await (FontLoader('MaterialIcons')..addFont(
                File(
                  '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              ))
              .load();
        });
        final detector = TransportDetector();
        final c = KineticLyricsController(
          nowPlaying: detector,
          lyrics: LyricsRepository(providers: []),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: KineticLyricsApp(controller: c),
          ),
        );
        detector.add(
          NowPlayingSnapshot(
            access: NowPlayingAccess.granted,
            track: song(DateTime.now(), 8, state: PlaybackStatus.paused),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('NOW PLAYING · PAUSED'), findsOneWidget);
        expect(find.text('ADVERTISEMENT'), findsOneWidget);
        await tester.tapAt(const Offset(180, 450));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('Play'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Play'));
        await tester.tap(find.byTooltip('Play'));
        await tester.pump();
        expect(detector.commands, ['play']);
        await tester.ensureVisible(find.byType(Slider));
        await tester.drag(find.byType(Slider), const Offset(50, 0));
        await tester.pump();
        expect(detector.commands, contains('seek'));
        expect(detector.seekPosition, inInclusiveRange(0, 30000));
        if (scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/review/playback-paused.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Your performance'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await detector.close();
      },
    );
  }
}
