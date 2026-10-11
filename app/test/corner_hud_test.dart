import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/app/kinetic_lyrics_controller.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/main.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_snapshot.dart';
import 'widget_test.dart' as fixtures;

void main() {
  testWidgets(
    'quiet corner clock and title remain visible with hidden controls and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final detector = fixtures.TestDetector();
      final controller = KineticLyricsController(
        nowPlaying: detector,
        lyrics: LyricsRepository(providers: [fixtures.TestLyrics()]),
      );
      await tester.pumpWidget(KineticLyricsApp(controller: controller));
      detector.add(
        NowPlayingSnapshot(
          access: NowPlayingAccess.granted,
          track: fixtures.TestDetector.track(
            title:
                'A very long song title that should remain available to accessibility',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final clock = find.byKey(const Key('corner-local-time'));
      final title = find.byKey(const Key('corner-song-title'));
      expect(clock, findsOneWidget);
      expect(
        (tester.widget<Text>(clock)).data,
        matches(RegExp(r'^\d{2}:\d{2}$')),
      );
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
      expect(tester.getRect(clock).left, lessThan(tester.getRect(title).left));
      expect(tester.getRect(title).right, lessThanOrEqualTo(360));
      expect(find.text('Tap anywhere to hide controls'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await detector.close();
    },
  );
}
