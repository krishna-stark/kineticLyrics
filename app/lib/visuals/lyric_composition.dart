import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../lyrics/domain/lyric_timeline.dart';
import 'lyric_scene.dart';
import '../semantics/song_semantic_profile.dart';
import 'plain_type.dart';

enum CompositionFamily {
  spotlight,
  sculpture,
  assembly,
  dialogue,
  monument,
  intimate,
}

/// Complete words are shaped once, in prepared shots, rather than paragraphs.
class ComposedWord {
  ComposedWord(this.word, this.painter, this.origin, this.hero, this.index);
  final LyricWord word;
  final TextPainter painter;
  final Offset origin;
  final bool hero;
  final int index;
  Rect get bounds => origin & painter.size;
  ui.Image? _raster;
  bool rasterAttempted = false;
  bool _disposed = false;

  Future<void> rasterize(double pixelRatio) async {
    if (_disposed || rasterAttempted) return;
    rasterAttempted = true;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    painter.paint(canvas, const Offset(3, 3));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        ((painter.width + 6) * pixelRatio).ceil(),
        ((painter.height + 6) * pixelRatio).ceil(),
      );
      if (_disposed) {
        image.dispose();
      } else {
        _raster = image;
      }
    } catch (_) {
      /* Keep the flat text fallback if a texture cannot be made. */
    } finally {
      picture.dispose();
    }
  }

  void paint(Canvas canvas, double opacity) {
    final image = _raster;
    if (image == null) {
      PlainType.paint(canvas, painter, origin, bounds, opacity: opacity);
    } else {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        bounds.inflate(3),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..filterQuality = FilterQuality.low,
      );
    }
  }

  void dispose() {
    _disposed = true;
    _raster?.dispose();
    painter.dispose();
  }
}

class LyricShot {
  LyricShot(this.start, this.end, this.words, this.family, this.transition);
  final Duration start;
  final Duration end;
  final List<ComposedWord> words;
  final CompositionFamily family;
  final SemanticTransition transition;
  late final motion = LyricMotionPlan(this);
}

/// Prepared once per shot, never shaped or inferred on the render clock.
class LyricMotionPlan {
  LyricMotionPlan(LyricShot shot) {
    precise = shot.words.every(
      (w) =>
          w.word.confidence >= .7 &&
          w.word.provenance != TimingProvenance.estimated,
    );
    fast =
        (shot.end - shot.start).inMilliseconds /
            math.max(1, shot.words.length) <
        320;
    transition = shot.transition;
    entranceMs = fast
        ? 100
        : switch (transition) {
            SemanticTransition.dissolve => 260,
            SemanticTransition.lift => 220,
            SemanticTransition.slide => 180,
            SemanticTransition.impact => 150,
            SemanticTransition.scatter => 190,
          };
    // Verified words settle at their vocal onset. Estimated phrases receive
    // choreography only, with no pretence of word-accurate anticipation.
    anticipationMs = !precise
        ? 0
        : fast
        ? 70
        : switch (transition) {
            SemanticTransition.dissolve => 160,
            SemanticTransition.lift => 140,
            SemanticTransition.slide => 100,
            SemanticTransition.impact => 110,
            SemanticTransition.scatter => 130,
          };
    exitMs = fast
        ? 150
        : transition == SemanticTransition.dissolve
        ? 260
        : 220;
  }
  late final bool precise, fast;
  late final SemanticTransition transition;
  late final int entranceMs, anticipationMs, exitMs;
}

class LyricComposition {
  LyricComposition(this.shots);
  final List<LyricShot> shots;

  LyricShot? at(Duration position) {
    for (final shot in shots) {
      if (position >= shot.start && position < shot.end) return shot;
    }
    return null;
  }

  Iterable<LyricShot> visibleAt(
    Duration position, {
    bool reduced = false,
    int outgoingLimit = 2,
  }) sync* {
    if (reduced) {
      final active = at(position);
      if (active != null) yield active;
      return;
    }
    // At most two outgoing groups, one active group and one anticipated group.
    final outgoing = <LyricShot>[];
    for (final shot in shots) {
      if (position >= shot.end &&
          position < shot.end + Duration(milliseconds: shot.motion.exitMs)) {
        outgoing.add(shot);
      }
    }
    for (final shot in outgoing.skip(
      math.max(0, outgoing.length - outgoingLimit.clamp(0, 2)),
    )) {
      yield shot;
    }
    final active = at(position);
    if (active != null) yield active;
    for (final shot in shots) {
      if (position < shot.start &&
          position >=
              shot.start - Duration(milliseconds: shot.motion.anticipationMs)) {
        yield shot;
        break;
      }
    }
  }

  void dispose() {
    for (final shot in shots) {
      for (final word in shot.words) {
        word.dispose();
      }
    }
  }

  static CompositionFamily familyFor(
    LyricScene scene, [
    LineSemanticProfile? semantic,
  ]) {
    if (scene.refrain) return CompositionFamily.monument;
    if (scene.directed && scene.line.words.length <= 2) {
      return CompositionFamily.spotlight;
    }
    if (scene.mood == LyricMood.lonely) return CompositionFamily.intimate;
    final words = scene.line.words;
    final millis = (scene.line.end - scene.line.start).inMilliseconds;
    if (words.isNotEmpty && millis / words.length < 240) {
      return CompositionFamily.assembly;
    }
    if (scene.vocalRole != VocalRole.lead) return CompositionFamily.dialogue;
    if (scene.directed) {
      return switch (scene.mood) {
        LyricMood.quiet || LyricMood.romantic => CompositionFamily.intimate,
        LyricMood.heavy || LyricMood.urgent => CompositionFamily.sculpture,
        LyricMood.joyful => CompositionFamily.assembly,
        LyricMood.lonely => CompositionFamily.intimate,
      };
    }
    if (semantic != null && semantic.motionConfidence >= .65) {
      return switch (semantic.composition) {
        SemanticComposition.spotlight => CompositionFamily.spotlight,
        SemanticComposition.staggered => CompositionFamily.sculpture,
        SemanticComposition.paired => CompositionFamily.dialogue,
        SemanticComposition.drifting => CompositionFamily.intimate,
      };
    }
    return switch (scene.index % 4) {
      0 => CompositionFamily.sculpture,
      1 => CompositionFamily.spotlight,
      2 => CompositionFamily.dialogue,
      _ => CompositionFamily.assembly,
    };
  }

  static String fontFor(LyricScene scene, [LineSemanticProfile? semantic]) {
    final fast =
        scene.line.words.isNotEmpty &&
        (scene.line.end - scene.line.start).inMilliseconds /
                scene.line.words.length <
            300;
    final typography = scene.directed && scene.refrain
        ? (fast ? SemanticTypography.condensed : SemanticTypography.display)
        : scene.directed &&
              (scene.mood == LyricMood.romantic ||
                  scene.mood == LyricMood.lonely)
        ? SemanticTypography.elegant
        : !scene.directed &&
              semantic != null &&
              semantic.motionConfidence >= .65
        ? semantic.typography
        : switch (scene.typographyMood ?? scene.mood) {
            LyricMood.romantic ||
            LyricMood.lonely => SemanticTypography.elegant,
            LyricMood.heavy || LyricMood.urgent => SemanticTypography.condensed,
            LyricMood.joyful => SemanticTypography.soft,
            LyricMood.quiet => SemanticTypography.soft,
          };
    final lyrical =
        typography == SemanticTypography.elegant ||
        scene.vocalRole == VocalRole.response;
    final nativeSerif = lyrical && !scene.refrain && !fast;
    final text = scene.line.text;
    // Use real script-specific families rather than silently falling back to
    // the same system face for every Telugu/Tamil/Hindi scene.
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) {
      return nativeSerif ? 'NotoSerifTelugu' : 'NotoSansTelugu';
    }
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
      return nativeSerif ? 'NotoSerifTamil' : 'NotoSansTamil';
    }
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return nativeSerif ? 'NotoSerifDevanagari' : 'NotoSansDevanagari';
    }
    final choices = switch (typography) {
      SemanticTypography.condensed => const [
        'BebasNeue',
        'Anton',
        'Oswald',
        'SpaceGrotesk',
      ],
      SemanticTypography.elegant => const [
        'CormorantGaramond',
        'PlayfairDisplay',
        'DMSerifDisplay',
        'BodoniModa',
        'DancingScript',
      ],
      SemanticTypography.soft => const [
        'SpaceGrotesk',
        'Oswald',
        'PlayfairDisplay',
      ],
      SemanticTypography.display => const [
        'LyricDisplay',
        'Anton',
        'Cinzel',
        'BodoniModa',
      ],
    };
    // Hold an authored family through a phrase block, not a random font per word.
    return choices[((scene.fontSeed ?? (scene.index ~/ 4)) +
            (scene.vocalRole == VocalRole.response ? 1 : 0)) %
        choices.length];
  }

  /// Supporting words use a quieter contrasting face, selected with script
  /// coverage intact. A coherent pair replaces random per-word font changes.
  static String supportFontFor(
    LyricScene scene, [
    LineSemanticProfile? semantic,
  ]) {
    final hero = fontFor(scene, semantic);
    if (hero.contains('Telugu')) {
      return hero == 'NotoSerifTelugu' ? 'NotoSansTelugu' : 'NotoSerifTelugu';
    }
    if (hero.contains('Tamil')) {
      return hero == 'NotoSerifTamil' ? 'NotoSansTamil' : 'NotoSerifTamil';
    }
    if (hero.contains('Devanagari')) {
      return hero == 'NotoSerifDevanagari'
          ? 'NotoSansDevanagari'
          : 'NotoSerifDevanagari';
    }
    return hero == 'SpaceGrotesk' ? 'PlayfairDisplay' : 'SpaceGrotesk';
  }

  static LyricComposition prepare(
    LyricScene scene,
    Size bounds,
    TextDirection direction, {
    LineSemanticProfile? semantic,
  }) {
    final family = familyFor(scene, semantic);
    final font = fontFor(scene, semantic);
    final supportFont = supportFontFor(scene, semantic);
    final source = scene.line.words;
    if (source.isEmpty) return LyricComposition([]);
    // Short successive shots replace a shrinking, ever longer paragraph.
    // A fast delivery keeps four predictable slots; slow spotlight shots use two.
    final groupSize = switch (family) {
      CompositionFamily.spotlight => 2,
      CompositionFamily.intimate => 3,
      _ => 4,
    };
    final shots = <LyricShot>[];
    for (var first = 0; first < source.length; first += groupSize) {
      final end = math.min(source.length, first + groupSize);
      final group = source.sublist(first, end);
      var hero = 0;
      var score = -1.0;
      for (var i = 0; i < group.length; i++) {
        final candidate =
            (LyricScene.moodFor(group[i].text) != LyricMood.quiet ? 20 : 0) +
            group[i].stress * 10 +
            group[i].text.characters.length.toDouble();
        if (candidate > score) {
          score = candidate;
          hero = i;
        }
      }
      final painters = <TextPainter>[];
      final origins = List<Offset>.filled(group.length, Offset.zero);
      final rows = <List<int>>[];
      for (var i = 0; i < group.length;) {
        if (family == CompositionFamily.assembly && i + 1 < group.length) {
          rows.add([i, i + 1]);
          i += 2;
        } else if (i == hero) {
          rows.add([i++]);
        } else if (i + 1 < group.length && i + 1 != hero) {
          rows.add([i, i + 1]);
          i += 2;
        } else {
          rows.add([i++]);
        }
      }
      for (var i = 0; i < group.length; i++) {
        final isHero = i == hero;
        final paired = rows.firstWhere((row) => row.contains(i)).length > 1;
        final sculpted =
            family == CompositionFamily.sculpture && group.length > 2;
        final maxWidth =
            bounds.width *
            (sculpted
                ? (isHero ? .53 : .36)
                : paired
                ? .43
                : .93);
        final ceiling = family == CompositionFamily.assembly
            ? (isHero ? 62.0 : 48.0)
            : family == CompositionFamily.monument
            ? (isHero ? 110.0 : 38.0)
            : isHero
            ? 100.0
            : 34.0;
        TextStyle style(double size) => TextStyle(
          fontFamily: i == hero ? font : supportFont,
          fontSize: size,
          height:
              RegExp(r'[\u0900-\u097F\u0B80-\u0C7F]').hasMatch(group[i].text)
              ? 1.18
              : 1.04,
          fontWeight: i == hero ? FontWeight.w700 : FontWeight.w500,
          letterSpacing:
              RegExp(r'[\u0900-\u097F\u0B80-\u0C7F]').hasMatch(group[i].text)
              ? 0
              : isHero
              ? -size * .035
              : size * .015,
          color: Colors.white,
          fontFamilyFallback: const [
            'NotoSansTelugu',
            'NotoSansTamil',
            'NotoSansDevanagari',
            'sans-serif',
          ],
        );
        final painter = TextPainter(
          textDirection: direction,
          text: TextSpan(
            text: isHero ? group[i].text.toUpperCase() : group[i].text,
            style: style(100),
          ),
        )..layout();
        final fontSize = math.min(
          ceiling,
          math.min(
                maxWidth / math.max(1, painter.width),
                bounds.height * .32 / math.max(1, painter.height),
              ) *
              100,
        );
        painter.text = TextSpan(
          text: isHero ? group[i].text.toUpperCase() : group[i].text,
          style: style(fontSize),
        );
        painter.layout();
        painters.add(painter);
      }
      final heights = [
        for (final row in rows)
          row.map((i) => painters[i].height).reduce(math.max),
      ];
      final totalHeight =
          heights.fold<double>(0, (sum, height) => sum + height) +
          (rows.length - 1) * 12;
      var y = -totalHeight / 2;
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final totalWidth =
            row.fold<double>(0, (sum, i) => sum + painters[i].width) +
            (row.length - 1) * 12;
        final spare = (bounds.width - totalWidth) / 2;
        final shift = switch (family) {
          CompositionFamily.sculpture => (rowIndex.isEven ? -.4 : .4) * spare,
          CompositionFamily.dialogue =>
            (scene.vocalRole == VocalRole.response ? .6 : -.6) * spare,
          CompositionFamily.intimate => -spare * .5,
          _ => 0.0,
        };
        var x = -totalWidth / 2 + shift;
        for (final i in row) {
          origins[i] = Offset(
            x,
            y + (heights[rowIndex] - painters[i].height) / 2,
          );
          x += painters[i].width + 12;
        }
        y += heights[rowIndex] + 12;
      }
      // A true asymmetric cluster: one large word and a supporting vertical
      // column. Assembly uses a stable two-column reading grid; monument keeps
      // the centered chorus hierarchy. These differ in geometry, not just seed.
      if (family == CompositionFamily.sculpture && group.length > 2) {
        final supporting = [
          for (var i = 0; i < group.length; i++)
            if (i != hero) i,
        ];
        final stackHeight =
            supporting.fold<double>(0, (sum, i) => sum + painters[i].height) +
            (supporting.length - 1) * 10;
        final left = scene.block.isEven;
        final heroX = left
            ? -bounds.width * .46
            : bounds.width * .46 - painters[hero].width;
        origins[hero] = Offset(heroX, -painters[hero].height / 2);
        var sy = -stackHeight / 2;
        for (final i in supporting) {
          origins[i] = Offset(
            left ? bounds.width * .10 : -bounds.width * .46,
            sy,
          );
          sy += painters[i].height + 10;
        }
      }
      shots.add(
        LyricShot(
          first == 0 ? scene.line.start : group.first.start,
          end == source.length ? scene.line.end : source[end].start,
          [
            for (var i = 0; i < group.length; i++)
              ComposedWord(group[i], painters[i], origins[i], i == hero, i),
          ],
          family,
          semantic != null && semantic.motionConfidence >= .65
              ? semantic.transition
              : switch (family) {
                  CompositionFamily.intimate =>
                    scene.mood == LyricMood.lonely
                        ? SemanticTransition.dissolve
                        : SemanticTransition.lift,
                  CompositionFamily.assembly ||
                  CompositionFamily.dialogue => SemanticTransition.slide,
                  CompositionFamily.sculpture => SemanticTransition.scatter,
                  CompositionFamily.monument ||
                  CompositionFamily.spotlight => SemanticTransition.impact,
                },
        ),
      );
    }
    return LyricComposition(shots);
  }
}
