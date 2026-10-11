import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/lyric_stage.dart';

void main() {
  testWidgets('stage treatments render complete phrases inside safe geometry', (
    tester,
  ) async {
    const size = Size(384, 832);
    for (final mood in LyricMood.values) {
      final line = LyricLine(
        text: switch (mood) {
          LyricMood.heavy => 'Feel the fire inside',
          LyricMood.romantic => 'ప్రేమ నీతో ప్రతి క్షణం',
          LyricMood.joyful => 'Dance into the light',
          LyricMood.urgent => 'Run toward tomorrow',
          LyricMood.lonely => 'I miss the rain',
          LyricMood.quiet => 'வானம் நம்மை அழைக்கிறது',
        },
        start: Duration.zero,
        end: const Duration(seconds: 5),
      );
      final shape = ShapedPhrase.fit(
        line,
        const Size(304, 580),
        TextDirection.ltr,
        mood: mood,
      );
      // Budget includes the title card, shallow depth and maximum beat scale.
      expect((shape.size.width + 16) * 1.016, lessThan(size.width * .86));
      expect((shape.size.height + 16) * 1.016, lessThan(size.height * .72));
      expect(shape.painter.computeLineMetrics().length, lessThanOrEqualTo(2));
      final padded = Rect.fromCenter(
        center: Offset.zero,
        width: shape.size.width + 16,
        height: shape.size.height + 16,
      );
      for (var step = 0; step <= 10; step++) {
        final matrix = LyricStage.perspective(step / 10, mood)
          ..scaleByDouble(1.016, 1.016, 1, 1);
        final transformed = [
          for (final point in [
            padded.topLeft,
            padded.topRight,
            padded.bottomLeft,
            padded.bottomRight,
          ])
            MatrixUtils.transformPoint(matrix, point),
        ];
        for (final point in transformed) {
          expect(point.dx.abs(), lessThan(size.width * .43));
          expect(point.dy.abs(), lessThan(size.height * .36));
        }
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.black, BlendMode.src);
      canvas.translate(size.width / 2, size.height / 2);
      final origin = Offset(-shape.size.width / 2, -shape.size.height / 2);
      LyricStage.paint(
        canvas,
        origin & shape.size,
        LyricScene(line, 0, mood, 0),
        const AudioFeatures(bass: .7, mid: .5, treble: .4, live: true),
        .7,
        .1,
        1,
        false,
      );
      shape.painter.paint(canvas, origin);
      final picture = recorder.endRecording();
      picture.dispose();
      shape.dispose();
    }
  });
}
