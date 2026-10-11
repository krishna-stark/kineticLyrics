import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/audio_features.dart';

/// Rounded, bottom-aligned spectrum bars, following the user's image reference.
/// Frequencies run low to high, left to right. No synthetic oscillation.
class SpectrumBars {
  SpectrumBars({this.outlined = true});
  final bool outlined;
  static const count = 40;
  final _levels = List<double>.filled(count, 0);
  double _lastTime = -1;
  static const redThreshold = .62;
  static const _red = Color(0xffef233c);

  void reset() {
    _levels.fillRange(0, count, 0);
    _lastTime = -1;
  }

  void paint(
    Canvas canvas,
    Size size,
    AudioFeatures audio,
    double time, {
    required double takeover,
    bool reduced = false,
    double opacity = 1,
  }) {
    if (time < _lastTime) reset();
    final dt = _lastTime < 0 ? 1 / 60 : (time - _lastTime).clamp(0.0, .05);
    if (time != _lastTime) {
      for (var i = 0; i < count; i++) {
        final target = audio.live ? _sample(audio, i / (count - 1)) : 0.0;
        final fraction = i / (count - 1);
        final tau = target > _levels[i]
            ? (fraction < .34
                  ? .022
                  : fraction < .73
                  ? .016
                  : .010)
            : (fraction < .34
                  ? .20
                  : fraction < .73
                  ? .13
                  : .075);
        _levels[i] += (target - _levels[i]) * (1 - math.exp(-dt / tau));
      }
      _lastTime = time;
    }
    final top = size.height * (2 / 3) * (1 - takeover.clamp(0, 1));
    final zone = Rect.fromLTRB(0, top, size.width, size.height);
    // One stationary height gradient, shared by every bar. Raising bars reveal
    // the red upper region; short bars remain white, with no whole-scene flash.
    final face =
        LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: .20),
            Colors.white,
            Colors.white,
            _red,
            _red,
          ],
          stops: const [0, .25, redThreshold, .85, 1],
        ).createShader(
          Rect.fromLTRB(
            0,
            zone.bottom - zone.height * .93,
            size.width,
            zone.bottom,
          ),
        );
    final baseline = zone.bottom;
    final pitch = size.width / count;
    final width = pitch * .66;
    canvas.save();
    canvas.clipRect(zone);
    for (var i = 0; i < count; i++) {
      final level = _levels[i];
      if (level < .005) continue;
      final height = zone.height * .93 * math.pow(level, .72);
      final x = pitch * (i + .5);
      final rect = Rect.fromLTWH(
        x - width / 2,
        baseline - height,
        width,
        height,
      );
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(width * .48));
      // One clean stroke per bar: black interior, no blur or reflective layers.
      canvas.drawRRect(
        shape,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1))
          ..shader = face
          ..style = outlined ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = (width * .23).clamp(1.25, 2.0),
      );
    }
    canvas.restore();
  }

  double _sample(AudioFeatures audio, double fraction) {
    if (audio.spectrum.isNotEmpty) {
      final position = fraction * (audio.spectrum.length - 1);
      final low = position.floor();
      final high = math.min(low + 1, audio.spectrum.length - 1);
      final value =
          audio.spectrum[low] +
          (audio.spectrum[high] - audio.spectrum[low]) * (position - low);
      final bandAttack = fraction < .34
          ? audio.bassOnset
          : fraction < .73
          ? audio.midOnset
          : audio.trebleOnset;
      return (value * 1.6 * (1 + bandAttack * .85)).clamp(0, 1);
    }
    // Older bridges supply three measured bands. Never invent frequency detail.
    return fraction < .34
        ? audio.bass
        : fraction < .73
        ? audio.mid
        : audio.treble;
  }
}
