import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/audio_features.dart';
import '../audio/music_state.dart';
import 'performance_settings.dart';

enum InstrumentalStyle { spectrum, waveform, contour }

class InstrumentalField {
  static InstrumentalStyle choose(MusicProfile profile, AudioFeatures audio) =>
      audio.waveform.isEmpty
      ? InstrumentalStyle.spectrum
      : switch (profile) {
          MusicProfile.melodic ||
          MusicProfile.lofi => InstrumentalStyle.waveform,
          MusicProfile.balanced => InstrumentalStyle.contour,
          _ => InstrumentalStyle.spectrum,
        };

  static void paint(
    Canvas canvas,
    Size size,
    AudioFeatures audio, {
    required double reveal,
    required InstrumentalStyle style,
    PerformanceSettings settings = const PerformanceSettings(),
  }) {
    if (reveal < .001 ||
        !audio.live ||
        audio.waveform.length < 2 ||
        style == InstrumentalStyle.spectrum) {
      return;
    }
    final zone = Rect.fromLTWH(
      24,
      size.height * .20,
      size.width - 48,
      size.height * .60,
    );
    final midline = zone.center.dy;
    final wave = audio.waveform;
    canvas.save();
    canvas.clipRect(zone.inflate(2));
    final amplitude = zone.height * .32 * (.5 + .5 * settings.motion) * reveal;
    // Three clean contours derived from the measured waveform. No tunnels,
    // random particles, blur, rotation or synthetic frequency detail.
    for (
      var layer = style == InstrumentalStyle.waveform ? 0 : 2;
      layer >= 0;
      layer--
    ) {
      final path = Path();
      for (var i = 0; i < wave.length; i++) {
        final x = zone.left + i / (wave.length - 1) * zone.width;
        final envelope = math.sin(math.pi * i / (wave.length - 1));
        final body = style == InstrumentalStyle.contour
            ? wave[i] * (1 - layer * .22) + (layer - 1) * audio.mid * .14
            : wave[i];
        final y = midline + body * amplitude * envelope;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer == 0 ? 1.6 + audio.trebleOnset * .6 : 1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(
            alpha: reveal * (layer == 0 ? .84 : .12),
          ),
      );
      if (style == InstrumentalStyle.waveform) break;
    }
    canvas.restore();
  }
}
