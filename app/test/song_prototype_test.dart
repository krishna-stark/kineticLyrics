import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import '../tool/review_prototypes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final prototype in ReviewPrototype.all) {
    test(
      'entire ${prototype.name} timeline fits with stable phrase geometry',
      () {
        final timeline = LyricScene.readableTimeline(prototype.timeline);
        final scenes = LyricScene.prepare(timeline);
        final shapes = {
          for (final scene in scenes)
            scene.index: ShapedPhrase.fit(
              scene.line,
              const Size(309, 550),
              TextDirection.ltr,
              mood: scene.mood,
            ),
        };
        for (var ms = 0; ms < 180000; ms += 50) {
          final position = Duration(milliseconds: ms);
          final index = timeline.indexAt(position);
          if (index < 0 || position >= timeline.lines[index].end) continue;
          final shape = shapes[index]!;
          expect(shape.size.width, lessThanOrEqualTo(309.1));
          expect(shape.size.height, lessThanOrEqualTo(550.1));
          expect(
            shape.painter.computeLineMetrics().length,
            lessThanOrEqualTo(2),
          );
        }
        for (final shape in shapes.values) {
          shape.dispose();
        }
        if (prototype == ReviewPrototype.fast) {
          expect(
            timeline.lines.length,
            lessThan(prototype.timeline.lines.length ~/ 2),
          );
        }
      },
    );
  }
}
