import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'lyric_scene.dart';

class WordPose {
  const WordPose(this.opacity, this.offset, this.scale, this.turnY, this.turnX);
  final double opacity;
  final Offset offset;
  final double scale;
  final double turnY;
  final double turnX;
  static const settled = WordPose(1, Offset.zero, 1, 0, 0);

  static WordPose sample({
    required LyricMood mood,
    required int index,
    required int count,
    required double age,
    required double phraseDuration,
    required double wordStart,
    required double wordDuration,
  }) {
    final entryLength = math.min(220.0, math.max(70.0, wordDuration * .55));
    final arrival = ((age - wordStart) / entryLength).clamp(0.0, 1.0);
    final e = arrival * arrival * (3 - 2 * arrival);
    final edge = math.min(240.0, phraseDuration * .12);
    final stagger = edge * .35 * index / math.max(1, count - 1);
    final departure =
        ((age - phraseDuration + edge - stagger) / (edge - stagger)).clamp(
          0.0,
          1.0,
        );
    final d = departure * departure * (3 - 2 * departure);
    final upcoming = age < wordStart;
    final side = index.isEven ? 1.0 : -1.0;
    final quiet = mood == LyricMood.lonely;
    return WordPose(
      (upcoming ? .34 : .34 + .66 * e) * (1 - d),
      upcoming
          ? Offset.zero
          : Offset(
              quiet ? 0 : side * 5 * (1 - e) - side * 4 * d,
              (quiet ? 4 : 10) * (1 - e) - (index.isEven ? 8 : -6) * d,
            ),
      upcoming ? 1 : (quiet ? .96 + .04 * e : .84 + .16 * e) * (1 - .12 * d),
      upcoming || quiet ? 0 : side * (.72 * (1 - e) - .48 * d),
      upcoming || quiet ? 0 : -.24 * (1 - e) + .35 * d,
    );
  }

  Matrix4 get matrix => Matrix4.identity()
    ..setEntry(3, 2, .0008)
    ..translateByDouble(offset.dx, offset.dy, 0, 1)
    ..rotateY(turnY)
    ..rotateX(turnX)
    ..scaleByDouble(scale, scale, 1, 1);
}
