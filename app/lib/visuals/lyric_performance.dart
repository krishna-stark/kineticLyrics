import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../lyrics/domain/lyric_timeline.dart';
import 'lyric_composition.dart';
import 'lyric_scene.dart';
import 'performance_settings.dart';
import '../semantics/song_semantic_profile.dart';

class VocalWordPose {
  const VocalWordPose(
    this.opacity,
    this.scale,
    this.dx,
    this.dy,
    this.turn, [
    this.reveal = 1,
  ]);
  final double opacity, scale, dx, dy, turn, reveal;

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
    final motion = shot.motion;
    final reliable = precise(item.word);
    final age = (position - shot.start).inMilliseconds.toDouble();
    final span = math.max(
      1.0,
      (shot.end - shot.start).inMilliseconds.toDouble(),
    );
    final onset = reliable
        ? math.max(
            0.0,
            (item.word.start - shot.start).inMilliseconds.toDouble(),
          )
        : item.index * (motion.fast ? 32.0 : 60.0);
    final anticipation = motion.precise
        ? motion.anticipationMs.toDouble()
        : 0.0;
    final entry = motion.precise
        ? anticipation
        : math.min(
            motion.fast ? 160.0 : math.max(260.0, motion.entranceMs.toDouble()),
            math.max(90, span * .35),
          );
    final progress = ((age - onset + anticipation) / entry).clamp(0.0, 1.0);
    if (age < onset - anticipation) return const VocalWordPose(0, 1, 0, 0, 0);
    // Decelerate into the hold; acceleration and fading occur after the final
    // word's sung interval, rather than stealing its last 12% of screen time.
    final eased = 1 - math.pow(1 - progress, 3).toDouble();
    final incoming = 1 - eased;
    final departure = ((age - span) / motion.exitMs).clamp(0.0, 1.0);
    final exit = departure * departure;
    final duration = math.max(
      1.0,
      (item.word.end - item.word.start).inMilliseconds.toDouble(),
    );
    final retired = reliable && motion.fast && position >= item.word.end
        ? ((position - item.word.end).inMilliseconds / 220).clamp(0.0, 1.0)
        : 0.0;
    final active =
        reliable && position >= item.word.start && position < item.word.end;
    final held = active && duration > 700
        ? math.sin(math.pi * item.word.progressAt(position)) * .025 * intensity
        : 0.0;
    final pulse = active ? (bassHit * .018 + midHit * .010) * intensity : 0.0;
    final travel = shot.travel.vector;
    final weight = item.hero ? 1.0 : .65;
    double dx = 0, dy = 0, turn = 0, scale = 1;
    switch (motion.transition) {
      case SemanticTransition.lift:
        dx = travel.dx * (-incoming * 44 + exit * 32);
        dy = travel.dy * (-incoming * 44 + exit * 32);
        scale = 1 - incoming * .055 - exit * .06;
      case SemanticTransition.dissolve:
        dx = travel.dx * (-incoming * 14 + exit * 16);
        dy = travel.dy * (-incoming * 14 + exit * 16);
        scale = 1 - incoming * .025 - exit * .04;
      case SemanticTransition.slide:
        dx = travel.dx * (-incoming * 56 + exit * 40);
        dy = travel.dy * (-incoming * 56 + exit * 40);
        scale = 1 - incoming * .04 - exit * .16;
      case SemanticTransition.impact:
        // A single bounded overshoot with a settled, readable hold.
        final overshoot = math.sin(math.pi * progress) * .045 * weight;
        scale = 1 - incoming * .18 * weight + overshoot - exit * .12;
        dx = travel.dx * (-incoming * 24 + exit * 28);
        dy = travel.dy * (-incoming * 24 + exit * 28);
      case SemanticTransition.scatter:
        final direction = item.index.isEven ? -1.0 : 1.0;
        final along = -incoming * 36 + exit * (26 + item.index * 3);
        final across = direction * (incoming * 10 + exit * 12);
        dx = travel.dx * along - travel.dy * across;
        dy = travel.dy * along + travel.dx * across;
        turn = direction * (incoming * .16 - exit * .10);
        scale = 1 - incoming * .10 - exit * .18;
    }
    // Separate visibility from travel: the word becomes legible while the
    // entrance is still moving, rather than spending the motion invisibly.
    final visible = (progress * 2.2).clamp(0.0, 1.0);
    final opacity = visible * (1 - exit) * (1 - retired * .52);
    return VocalWordPose(
      opacity,
      1 + (scale - 1) * intensity - retired * .15 + held + pulse,
      dx * intensity + travel.dx * retired * 10,
      dy * intensity + travel.dy * retired * 10,
      turn * intensity,
      motion.transition == SemanticTransition.lift ? eased : 1,
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
    bool handoff = false,
    int outgoingLimit = 2,
  }) {
    for (final shot in composition.visibleAt(
      position,
      reduced: reduced,
      outgoingLimit: outgoingLimit,
    )) {
      _paintShot(
        canvas,
        size,
        scene,
        shot,
        position,
        settings: settings,
        reduced: reduced,
        bassHit: bassHit,
        midHit: midHit,
        opacity: opacity,
        echo: echo,
        simultaneous: simultaneous,
        handoff: handoff || shot != composition.shots.last,
      );
    }
  }

  static void _paintShot(
    Canvas canvas,
    Size size,
    LyricScene scene,
    LyricShot shot,
    Duration position, {
    required PerformanceSettings settings,
    required bool reduced,
    required double bassHit,
    required double midHit,
    required double opacity,
    required bool echo,
    required bool simultaneous,
    required bool handoff,
  }) {
    final role = scene.vocalRole;
    final side = role == VocalRole.response ? 1.0 : -1.0;
    final retreatProgress = handoff && !reduced && !echo && !simultaneous
        ? ((position - shot.end).inMilliseconds + 140) / 140.0
        : 0.0;
    final retreat = Curves.easeInOutCubic.transform(
      retreatProgress.clamp(0.0, 1.0),
    );
    final roleScale =
        (1 - retreat * .4) *
        (simultaneous
            ? .55
            : role == VocalRole.backing || echo
            ? .66
            : 1.0);
    final travel = shot.travel.vector;
    final center = Offset(
      size.width *
              (.5 +
                  (simultaneous
                      ? side * .23
                      : role == VocalRole.response
                      ? .035
                      : role == VocalRole.lead
                      ? 0
                      : -.035)) +
          travel.dx * size.width * .18 * retreat,
      size.height *
              (echo
                  ? .14
                  : role == VocalRole.backing
                  ? .22
                  : 1 / 3) +
          travel.dy * size.height * .14 * retreat,
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
      if (pose.reveal < 1) {
        final padded = rect.inflate(3);
        final reveal = switch (shot.travel) {
          LyricTravel.leftToRight => Rect.fromLTWH(
            padded.left,
            padded.top,
            padded.width * pose.reveal,
            padded.height,
          ),
          LyricTravel.rightToLeft => Rect.fromLTWH(
            padded.right - padded.width * pose.reveal,
            padded.top,
            padded.width * pose.reveal,
            padded.height,
          ),
          LyricTravel.topToBottom => Rect.fromLTWH(
            padded.left,
            padded.top,
            padded.width,
            padded.height * pose.reveal,
          ),
          LyricTravel.bottomToTop => Rect.fromLTWH(
            padded.left,
            padded.bottom - padded.height * pose.reveal,
            padded.width,
            padded.height * pose.reveal,
          ),
        };
        canvas.clipRect(reveal);
      }
      item.paint(
        canvas,
        pose.opacity * opacity * (role == VocalRole.backing ? .68 : 1),
      );
      canvas.restore();
    }
    canvas.restore();
  }
}
