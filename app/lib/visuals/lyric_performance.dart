import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../lyrics/domain/lyric_timeline.dart';
import 'lyric_composition.dart';
import 'lyric_scene.dart';
import 'performance_settings.dart';

class VocalWordPose {
  const VocalWordPose(this.opacity, this.scale, this.dx, this.dy, this.turn);
  final double opacity, scale, dx, dy, turn;

  static bool precise(LyricWord word) =>
      word.confidence >= .7 && word.provenance != TimingProvenance.estimated;

  static VocalWordPose sample({
    required ComposedWord item,
    required LyricShot shot,
    required LyricScene scene,
    required Duration position,
    required double intensity,
    bool reduced = false,
    double bassHit = 0,
    double midHit = 0,
  }) {
    if (reduced) return const VocalWordPose(1, 1, 0, 0, 0);
    final reliable = precise(item.word);
    final age = (position - shot.start).inMilliseconds.toDouble();
    final span = math.max(
      1.0,
      (shot.end - shot.start).inMilliseconds.toDouble(),
    );
    // Estimated timings describe phrase flow only. Do not hide individual
    // words behind invented vocal timestamps.
    final onset = reliable
        ? math.max(
            0.0,
            (item.word.start - shot.start).inMilliseconds.toDouble(),
          )
        : item.index * 26.0;
    final duration = math.max(
      1.0,
      (item.word.end - item.word.start).inMilliseconds.toDouble(),
    );
    if (age < onset) return const VocalWordPose(0, 1, 0, 0, 0);
    final fast = span / shot.words.length < 320;
    final entry = reliable
        ? math.min(fast ? 100.0 : 200.0, duration * .3).clamp(45.0, 200.0)
        : 150.0;
    final progress = ((age - onset) / entry).clamp(0.0, 1.0);
    final incoming = math.pow(1 - progress, 3).toDouble();
    final exitLength = math.min(180.0, span * .12);
    final departing = ((age - span + exitLength) / exitLength).clamp(0.0, 1.0);
    final exit = departing * departing;
    final retired = reliable && fast && position >= item.word.end
        ? ((position - item.word.end).inMilliseconds / 170).clamp(0.0, 1.0)
        : 0.0;
    final active =
        reliable && position >= item.word.start && position < item.word.end;
    final held = active && duration > 700
        ? math.sin(math.pi * item.word.progressAt(position)) * .025 * intensity
        : 0.0;
    final stress = item.word.stress.clamp(0.0, 1.0);
    final pulse = active ? (bassHit * .014 + midHit * .008) * intensity : 0.0;
    final quiet = shot.family == CompositionFamily.intimate;
    final side = item.index.isEven ? -1.0 : 1.0;
    final opacity = (1 - incoming) * (1 - exit) * (1 - retired * .58);
    return VocalWordPose(
      opacity,
      1 -
          incoming * (quiet ? .04 : .12 + stress * .03) * intensity -
          exit * .08 * intensity -
          retired * .20 +
          held +
          pulse,
      quiet ? 0 : side * (incoming * 10 + exit * 12) * intensity,
      (incoming * (quiet ? 7 : 20) - exit * (quiet ? 9 : 16)) * intensity,
      quiet ? 0 : side * (incoming * .5 - exit * .3) * intensity,
    );
  }
}

/// Shared by live performance, saved-moment replay and export. All shaped
/// glyphs belong to the prepared composition; this loop only draws them.
class LyricPerformance {
  static void paint(
    Canvas canvas,
    Size size,
    LyricScene scene,
    LyricComposition composition,
    Duration position, {
    PerformanceSettings settings = const PerformanceSettings(),
    bool reduced = false,
    double bassHit = 0,
    double midHit = 0,
    double opacity = 1,
    bool echo = false,
    bool simultaneous = false,
  }) {
    final shot = composition.at(position);
    if (shot == null) return;
    final role = scene.vocalRole;
    final side = role == VocalRole.response ? 1.0 : -1.0;
    final roleScale = simultaneous
        ? .55
        : role == VocalRole.backing || echo
        ? .66
        : 1.0;
    final center = Offset(
      size.width *
          (.5 +
              (simultaneous
                  ? side * .23
                  : role == VocalRole.response
                  ? .035
                  : role == VocalRole.lead
                  ? 0
                  : -.035)),
      size.height *
          (echo
              ? .14
              : role == VocalRole.backing
              ? .22
              : 1 / 3),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(roleScale);
    for (final item in shot.words) {
      final pose = VocalWordPose.sample(
        item: item,
        shot: shot,
        scene: scene,
        position: position,
        intensity: settings.motion,
        reduced: reduced,
        bassHit: bassHit,
        midHit: midHit,
      );
      if (pose.opacity <= .001) continue;
      final rect = item.bounds;
      canvas.save();
      canvas.translate(rect.center.dx + pose.dx, rect.center.dy + pose.dy);
      final transform = Matrix4.identity()
        ..setEntry(3, 2, .0008)
        ..rotateY(pose.turn)
        ..scaleByDouble(pose.scale, pose.scale, 1, 1);
      canvas.transform(transform.storage);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      item.paint(
        canvas,
        pose.opacity * opacity * (role == VocalRole.backing ? .68 : 1),
      );
      canvas.restore();
    }
    canvas.restore();
  }
}
