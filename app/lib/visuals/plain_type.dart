import 'package:flutter/material.dart';

/// Flat glyphs. Fully visible words need no offscreen material/compositing pass.
class PlainType {
  static void paint(
    Canvas canvas,
    TextPainter text,
    Offset origin,
    Rect bounds, {
    double opacity = 1,
  }) {
    if (opacity <= .001) return;
    if (opacity >= .995) {
      text.paint(canvas, origin);
      return;
    }
    canvas.saveLayer(
      bounds.inflate(2),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    text.paint(canvas, origin);
    canvas.restore();
  }
}
