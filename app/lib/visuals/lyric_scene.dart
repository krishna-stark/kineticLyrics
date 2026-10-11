import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../semantics/lyric_cues.dart';

enum LyricMood { quiet, lonely, romantic, heavy, urgent, joyful }

enum SongSection { intro, verse, refrain, instrumental, outro }

/// Prepared at timeline arrival. No semantic or layout decisions on audio ticks.
class LyricScene {
  LyricScene(
    this.line,
    this.index,
    this.mood,
    this.motif, {
    this.refrain = false,
    this.recurrence = 1,
    this.section = SongSection.verse,
    this.block = 0,
    this.fontSeed,
    this.vocalRole = VocalRole.lead,
    this.directed = false,
    this.typographyMood,
  }) : hasLyrics =
           line.text.trim().isNotEmpty &&
           !RegExp(
             r'^[\[(](instrumental|intro|outro|music|interlude)[\])]$',
             caseSensitive: false,
           ).hasMatch(line.text.trim());
  final bool hasLyrics;
  final LyricLine line;
  final int index;
  final LyricMood mood;
  final int motif;
  final bool refrain;
  final int recurrence;
  final SongSection section;
  final int block;
  final int? fontSeed;
  final VocalRole vocalRole;
  final bool directed;
  final LyricMood? typographyMood;

  static LyricTimeline readableTimeline(LyricTimeline timeline) {
    final enriched = timeline.enrich();
    final lines = <LyricLine>[];
    for (var i = 0; i < enriched.lines.length; i++) {
      final first = enriched.lines[i];
      var last = first;
      final words = List<LyricWord>.of(first.words);
      // Fast adjacent lines become one phrase before entrance, never mid-lyric.
      while (first.text.trim().isNotEmpty &&
          (last.end - first.start).inMilliseconds < 1200 &&
          i + 1 < enriched.lines.length) {
        final next = enriched.lines[i + 1];
        if (next.text.trim().isEmpty ||
            next.vocalRole != first.vocalRole ||
            (next.start - last.end).inMilliseconds.abs() > 100 ||
            (next.end - next.start).inMilliseconds >= 800 ||
            words.length + next.words.length > 12) {
          break;
        }
        words.addAll(next.words);
        last = next;
        i++;
      }
      lines.add(
        LyricLine(
          text: words.map((w) => w.text).join(' '),
          start: first.start,
          end: last.end,
          words: words,
          confidence: first.confidence,
          provenance: first.provenance,
          vocalRole: first.vocalRole,
        ),
      );
    }
    return LyricTimeline(
      provider: timeline.provider,
      quality: timeline.quality,
      lines: lines,
    );
  }

  static List<LyricScene> prepare(LyricTimeline timeline) {
    final motifs = <String, int>{};
    final counts = <String, int>{};
    final occurrences = <String, int>{};
    for (final line in timeline.lines) {
      final key = line.text.trim().toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < timeline.lines.length; i++)
        (() {
          final line = timeline.lines[i];
          final key = line.text.trim().toLowerCase();
          final recurrence = occurrences[key] = (occurrences[key] ?? 0) + 1;
          return LyricScene(
            line,
            i,
            moodFor(line.text),
            motifs.putIfAbsent(key, () => motifs.length),
            refrain: counts[key]! > 1,
            recurrence: recurrence,
          );
        })(),
    ];
  }

  static LyricMood moodFor(String text) {
    final value = text.toLowerCase();
    bool native(String terms) => LyricCues.contains(value, terms.split('|'));
    if (native(
      r'ఒంటరి|కన్నీ|தனிமை|கண்ணீர்|अकेल|तन्हा|आँसू|kanneer|kanniru|tanhai',
    )) {
      return LyricMood.lonely;
    }
    if (native(
      r'ప్రేమ|కాదల్|காதல்|அன்பு|प्यार|मोहब्बत|kaadhal|kadhal|prema|mohabbat|pyaar',
    )) {
      return LyricMood.romantic;
    }
    if (native(r'అగ్ని|కోపం|நெருப்பு|கோபம்|गुस्सा|आग|neruppu|kopam|gussa')) {
      return LyricMood.heavy;
    }
    if (native(
      r'ఆనందం|సంతోషం|மகிழ்ச்சி|खुशी|aanandam|santhosham|magizhchi|khushi',
    )) {
      return LyricMood.joyful;
    }
    // Conservative local cues: unknown text keeps the restrained reference scene.
    if (RegExp(
      r'(?:^|\s)(run|hurry|now|chase|catch|prove|escape|రా|வா)(?:$|\s|[,.!?])',
    ).hasMatch(value)) {
      return LyricMood.urgent;
    }
    if (RegExp(
      r'\b(fire|fight|anger|break|heavy|burn|hurt|hurts|blood|trouble)\b',
    ).hasMatch(value)) {
      return LyricMood.heavy;
    }
    if (RegExp(
      r'(?:^|\s)(love|kiss|heart|touch|feel|closer|need|ప్రేమ|காதல்)(?:$|\s|[,.!?])',
    ).hasMatch(value)) {
      return LyricMood.romantic;
    }
    if (RegExp(
      r'\b(alone|lonely|lost|empty|cry|rain|wrong|gone|miss|disappear|vanish|forget|tears)\b',
    ).hasMatch(value)) {
      return LyricMood.lonely;
    }
    if (RegExp(
      r'\b(dance|joy|shine|happy|sun|alive|freedom|dream|light|night|stars)\b',
    ).hasMatch(value)) {
      return LyricMood.joyful;
    }
    return LyricMood.quiet;
  }
}

class ShapedPhrase {
  ShapedPhrase(this.painter, this.wordRanges);
  final TextPainter painter;
  final List<TextRange> wordRanges;
  late final List<List<Rect>> wordBoxes = [
    for (final range in wordRanges)
      painter
          .getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          )
          .map((box) => box.toRect())
          .toList(),
  ];
  Size get size => painter.size;
  void dispose() => painter.dispose();

  static TextSpan _hierarchy(String text, double size, LyricMood mood) {
    final words = RegExp(r'\S+').allMatches(text).toList();
    final cues = switch (mood) {
      LyricMood.romantic =>
        r'love|kiss|heart|touch|feel|closer|need|ప్రేమ|காதல்',
      LyricMood.lonely =>
        r'alone|lonely|lost|empty|cry|rain|wrong|gone|miss|disappear|vanish|forget|tears',
      LyricMood.heavy =>
        r'fire|fight|anger|break|heavy|burn|hurt|hurts|blood|trouble',
      LyricMood.joyful =>
        r'dance|joy|shine|happy|sun|alive|freedom|dream|light|night|stars',
      LyricMood.urgent => r'run|hurry|now|chase|catch|prove|escape|రా|வா',
      LyricMood.quiet => r'(?!)',
    };
    final cue = RegExp('^(?:$cues)[,.!?]*\$');
    final hero = words.indexWhere(
      (word) => cue.hasMatch(word.group(0)!.toLowerCase()),
    );
    final children = <InlineSpan>[];
    var end = 0;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      children.add(TextSpan(text: text.substring(end, word.start)));
      children.add(
        TextSpan(
          text: word.group(0),
          style: TextStyle(
            fontSize:
                size *
                (hero < 0
                    ? 1
                    : i == hero
                    ? 1.12
                    : .88),
            fontWeight: i == hero ? FontWeight.w800 : FontWeight.w700,
            color:
                i == hero &&
                    (mood == LyricMood.heavy || mood == LyricMood.urgent)
                ? const Color(0xffef6262)
                : const Color(0xfffff4e6),
          ),
        ),
      );
      end = word.end;
    }
    children.add(TextSpan(text: text.substring(end)));
    return TextSpan(
      style: TextStyle(
        fontSize: size,
        height: 1.16,
        letterSpacing: -size * .02,
        fontFamilyFallback: const [
          'Noto Sans Telugu',
          'Noto Sans Tamil',
          'sans-serif',
        ],
      ),
      children: children,
    );
  }

  /// Wrap at whitespace only. Indic conjuncts and long single words are shaped
  /// intact, then scaled down. Geometry is fixed for the complete phrase.
  static ShapedPhrase fit(
    LyricLine line,
    Size bounds,
    TextDirection direction, {
    LyricMood mood = LyricMood.quiet,
  }) {
    final words = line.text.trim().split(RegExp(r'\s+'));
    final candidates = <String>[words.join(' ')];
    for (var split = 1; split < words.length; split++) {
      candidates.add(
        '${words.take(split).join(' ')}\n${words.skip(split).join(' ')}',
      );
    }
    var bestSize = 0.0;
    var best = candidates.first;
    final ceiling = switch (mood) {
      LyricMood.lonely => 48.0,
      LyricMood.heavy => 76.0,
      LyricMood.urgent => 58.0,
      _ => 68.0,
    };
    for (final candidate in candidates) {
      final measure = TextPainter(
        text: _hierarchy(candidate, 100, mood),
        textDirection: direction,
      )..layout();
      final fit = math.min(
        ceiling,
        math.min(
              bounds.width / math.max(1, measure.width),
              bounds.height / math.max(1, measure.height),
            ) *
            100,
      );
      if (fit > bestSize) {
        bestSize = fit * .98;
        best = candidate;
      }
      measure.dispose();
    }
    final painter = TextPainter(
      text: _hierarchy(best, bestSize, mood),
      textAlign: mood == LyricMood.lonely ? TextAlign.left : TextAlign.center,
      textDirection: direction,
    )..layout(minWidth: bounds.width, maxWidth: bounds.width);
    return ShapedPhrase(painter, [
      for (final match in RegExp(r'\S+').allMatches(best))
        TextRange(start: match.start, end: match.end),
    ]);
  }
}
