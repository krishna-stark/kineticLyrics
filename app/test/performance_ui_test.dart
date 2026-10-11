import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/app/performance_library.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/ui/performance_panel.dart';
import 'package:kinetic_lyrics/ui/moment_screen.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/performance_settings.dart';

void main() {
  testWidgets(
    'settings stay usable at large text size and update without a new song',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('performance-ui-'),
      ))!;
      final library = PerformanceLibrary(directory: () async => directory);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: PerformancePanel(library: library)),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Concert'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Concert'));
      await tester.pump();
      expect(library.settings.intensity, PerformanceIntensity.concert);
      await tester.scrollUntilVisible(
        find.text('Reduced motion'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Reduced motion'));
      await tester.pump();
      expect(library.settings.reduceMotion, isTrue);
      var pulses = 0;
      const haptics = MethodChannel('kinetic_lyrics/haptics');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (
        call,
      ) async {
        expect(call.method, 'pulse');
        pulses++;
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          haptics,
          null,
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Beat haptics'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.ensureVisible(find.text('Beat haptics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beat haptics'));
      await tester.pump();
      expect(library.settings.haptics, isTrue);
      expect(pulses, 1);
      await tester.scrollUntilVisible(
        find.text('Test vibration'),
        120,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Test vibration'));
      await tester.pump();
      expect(pulses, 2);
      await tester.tap(find.text('Moments'));
      await tester.pumpAndSettle();
      expect(find.text('Keep a moment that stays with you'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        library.dispose();
        await directory.delete(recursive: true);
      });
    },
  );

  testWidgets(
    'saved moment replays and exports a readable PNG only on an explicit tap',
    (tester) async {
      final moment = LyricMoment(
        identity: 'fixture',
        title: 'A saved song',
        artist: 'Artist',
        line: const LyricLine(
          text: 'Hold the rhythm',
          start: Duration.zero,
          end: Duration(seconds: 4),
        ),
        mood: LyricMood.quiet,
        section: SongSection.verse,
        fontSeed: 5,
      );
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('kinetic_lyrics/moments'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MomentScreen(
            moment: moment,
            settings: const PerformanceSettings(reduceMotion: true),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(calls, isEmpty);
      expect(find.text('Visual replay · no recorded audio'), findsOneWidget);
      await tester.tap(find.byTooltip('Share visual card'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(calls.length, 1);
      expect(calls.first.method, 'shareImage');
      final payload = calls.first.arguments as Map;
      final png = payload['png'] as List<int>;
      expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(payload.containsKey('audio'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('kinetic_lyrics/moments'),
        null,
      );
    },
  );
}
