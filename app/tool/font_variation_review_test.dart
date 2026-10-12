import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_performance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'review prepared phrase font variants through production renderer',
    () async {
      for (final family in [
        'SpaceGrotesk',
        'DancingScript',
        'PlayfairDisplay',
        'Anton',
      ]) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
      }
      const size = Size(360, 640);
      final line = LyricTimeline(
        provider: 'review',
        quality: LyricsTimingQuality.lineSynced,
        lines: [
          LyricLine(
            text: 'Feel the music',
            start: Duration.zero,
            end: const Duration(seconds: 5),
          ),
        ],
      ).enrich().lines.first;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      final compositions = <LyricComposition>[];
      final labels = <TextPainter>[];
      for (var i = 0; i < 4; i++) {
        final scene = LyricScene(
          line,
          i * 4,
          LyricMood.quiet,
          0,
          directed: true,
          fontSeed: 0,
        );
        final composition = LyricComposition.prepare(
          scene,
          const Size(300, 350),
          TextDirection.ltr,
        );
        compositions.add(composition);
        canvas.save();
        canvas.translate(i * size.width, 0);
        LyricPerformance.paint(
          canvas,
          size,
          scene,
          composition,
          const Duration(milliseconds: 1600),
        );
        final label = TextPainter(
          text: TextSpan(
            text: 'Phrase group ${i + 1}\n${LyricComposition.fontFor(scene)}',
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, const Offset(24, 460));
        labels.add(label);
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1440, 640);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/review/font-phrase-variants.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      for (final composition in compositions) {
        composition.dispose();
      }
      for (final label in labels) {
        label.dispose();
      }
      image.dispose();
      picture.dispose();
    },
  );
}
