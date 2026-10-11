import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/audio_features.dart';
import 'lyric_scene.dart';

/// Original vector set pieces. Foreground glyphs retain their prepared geometry.
class LyricStage {
  static const ink = Color(0xffed5555);
  static const paper = Color(0xfffff4e6);
  static Matrix4 perspective(double visibility, LyricMood mood) {
    final turn = 1 - visibility.clamp(0.0, 1.0);
    return Matrix4.identity()
      ..setEntry(3, 2, .0006)
      ..rotateY((mood == LyricMood.lonely ? -.40 : .62) * turn)
      ..rotateX(-.20 * turn);
  }

  static void paint(
    Canvas canvas,
    Rect text,
    LyricScene scene,
    AudioFeatures audio,
    double beat,
    double beatAge,
    double time,
    bool reduced,
  ) {
    final r = text.inflate(8);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ink.withValues(alpha: .28 + beat * .32);
    final fill = Paint()..color = ink.withValues(alpha: .055 + beat * .06);
    if (scene.refrain) {
      // A chorus has a recognizable title-card silhouette, not another wave.
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        fill,
      );
      final reach = math.min(r.width * .18, 42.0) + beat * 5;
      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ]) {
        final dx = corner.dx == r.left ? 1.0 : -1.0;
        final dy = corner.dy == r.top ? 1.0 : -1.0;
        canvas.drawLine(corner, corner + Offset(dx * reach, 0), line);
        canvas.drawLine(corner, corner + Offset(0, dy * 8), line);
      }
      return;
    }
    switch (scene.mood) {
      case LyricMood.heavy:
        final plate = Path()
          ..moveTo(r.left, r.top + 8)
          ..lineTo(r.right - 8, r.top)
          ..lineTo(r.right, r.bottom - 8)
          ..lineTo(r.left + 8, r.bottom)
          ..close();
        canvas.drawPath(plate, fill);
        canvas.drawLine(r.bottomLeft, r.bottomRight, line..strokeWidth = 3);
        // Bass increases mass inside the plate, not foreground travel.
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.top, 3 + audio.bass * 4, r.height),
          Paint()..color = ink.withValues(alpha: .18 + beat * .25),
        );
      case LyricMood.urgent:
        for (final y in [r.top + 3, r.bottom - 3]) {
          canvas.drawLine(
            Offset(r.left, y),
            Offset(r.left + r.width * (.22 + beat * .26), y),
            line..strokeWidth = 2.5,
          );
        }
        final blade = Path()
          ..moveTo(r.right - 24, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right - 8, r.bottom)
          ..close();
        canvas.drawPath(blade, fill);
      case LyricMood.romantic:
        final breath = reduced ? 0.0 : math.sin(time * .6) * 2;
        for (final side in [-1.0, 1.0]) {
          final x = side < 0 ? r.left + 4 : r.right - 4;
          final path = Path()
            ..moveTo(x, r.top)
            ..cubicTo(
              x - side * (14 + audio.mid * 10 + breath),
              r.center.dy,
              x + side * 5,
              r.center.dy,
              x,
              r.bottom,
            );
          canvas.drawPath(
            path,
            line..color = paper.withValues(alpha: .13 + beat * .1),
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: r.center,
            width: r.width * .76,
            height: r.height * .95,
          ),
          Paint()
            ..shader = RadialGradient(
              colors: [
                ink.withValues(alpha: .10 + audio.bass * .05),
                Colors.transparent,
              ],
            ).createShader(r),
        );
      case LyricMood.joyful:
        // Stationary celebratory rays; hits expand once and disappear.
        final spread = reduced ? 0.0 : (beatAge / .35).clamp(0.0, 1.0) * 6;
        for (var i = 0; i < 12; i++) {
          final angle = i * math.pi / 6;
          final inner = Offset(
            math.cos(angle) * (r.width * .43),
            math.sin(angle) * (r.height * .40),
          );
          final outer = Offset(
            math.cos(angle) * (r.width * .46),
            math.sin(angle) * (r.height * .46),
          );
          canvas.drawLine(
            r.center + inner,
            r.center + outer + Offset(0, math.sin(angle) * spread),
            line,
          );
        }
      case LyricMood.lonely:
        canvas.drawLine(
          r.bottomLeft,
          Offset(r.left + r.width * .42, r.bottom),
          line..color = paper.withValues(alpha: .16),
        );
        canvas.drawCircle(
          Offset(r.right - 3, r.bottom),
          1.5,
          Paint()..color = ink.withValues(alpha: .35),
        );
      case LyricMood.quiet:
        canvas.drawLine(
          r.topLeft,
          Offset(r.left + 22, r.top),
          line..color = paper.withValues(alpha: .20),
        );
        canvas.drawLine(Offset(r.right - 22, r.bottom), r.bottomRight, line);
    }
  }
}
