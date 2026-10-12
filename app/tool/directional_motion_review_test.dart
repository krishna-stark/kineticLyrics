import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_performance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render four directional entrances, holds and handoffs', () async {
    for (final family in ['SpaceGrotesk', 'PlayfairDisplay']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    final line = LyricTimeline(
      provider: 'fixture',
      quality: LyricsTimingQuality.lineSynced,
      lines: [
        LyricLine(
          text: 'Feel the rhythm',
          start: const Duration(milliseconds: 300),
          end: const Duration(milliseconds: 2000),
        ),
      ],
    ).enrich().lines.first;
    final scene = LyricScene(
      line,
      0,
      LyricMood.quiet,
      0,
      directed: true,
      fontSeed: 0,
    );
    final compositions = <LyricComposition>[];
    for (final travel in LyricTravel.values) {
      final base = LyricComposition.prepare(
        scene,
        const Size(300, 350),
        TextDirection.ltr,
      );
      final composition = LyricComposition([
        for (final shot in base.shots)
          LyricShot(
            shot.start,
            shot.end,
            shot.words,
            shot.family,
            SemanticTransition.slide,
            travel: travel,
          ),
      ]);
      for (final word in composition.shots.expand((s) => s.words)) {
        await word.rasterize(2);
      }
      compositions.add(composition);
    }
    final folder = Directory('build/review/directional-motion');
    await folder.create(recursive: true);
    for (var frame = 0; frame < 72; frame++) {
      final position = Duration(milliseconds: frame * 35);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      final labels = <TextPainter>[];
      for (var i = 0; i < compositions.length; i++) {
        canvas.save();
        canvas.translate(i * 360.0, 0);
        canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 640));
        LyricPerformance.paint(
          canvas,
          const Size(360, 640),
          scene,
          compositions[i],
          position,
          handoff: true,
        );
        final label = TextPainter(
          text: TextSpan(
            text:
                '${LyricTravel.values[i].name}\n${position.inMilliseconds} ms',
            style: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, const Offset(20, 460));
        labels.add(label);
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1440, 640);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${folder.path}/${frame.toString().padLeft(3, '0')}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      for (final label in labels) {
        label.dispose();
      }
      image.dispose();
      picture.dispose();
    }
    for (final composition in compositions) {
      composition.dispose();
    }
  });
}
