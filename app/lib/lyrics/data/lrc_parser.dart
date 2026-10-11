import 'dart:math' as math;

import '../domain/lyric_timeline.dart';

class LrcParser {
  static final _timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  static final _wordTimestamp = RegExp(
    r'<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>',
  );
  static final _voice = RegExp(
    r'^\s*\[voice:(lead|response|backing|together)\]\s*',
    caseSensitive: false,
  );

  List<LyricLine> parse(String source, {required Duration? trackDuration}) {
    final entries =
        <({Duration start, String raw, Duration shift, VocalRole role})>[];
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final matches = _timestamp.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;
      var text = rawLine.substring(matches.last.end).trim();
      final voice = _voice.firstMatch(text);
      final role = voice == null
          ? VocalRole.lead
          : VocalRole.values.byName(voice.group(1)!.toLowerCase());
      if (voice != null) text = text.substring(voice.end);
      for (final match in matches) {
        final start = _parseTimestamp(match);
        entries.add((
          start: start,
          raw: text,
          shift: start - _parseTimestamp(matches.first),
          role: role,
        ));
      }
    }
    entries.sort((a, b) => a.start.compareTo(b.start));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final fallbackEnd = entry.start + const Duration(seconds: 4);
      final end = index + 1 < entries.length
          ? entries[index + 1].start
          : trackDuration ?? fallbackEnd;
      final safeEnd = end > entry.start ? end : fallbackEnd;
      final rawText = entry.raw.replaceAll(_wordTimestamp, '').trim();
      final verified = _parseWords(
        entry.raw,
        entry.start,
        safeEnd,
        entry.shift,
      );
      final text = verified?.map((w) => w.text).join(' ') ?? rawText;
      return LyricLine(
        text: text,
        start: entry.start,
        end: safeEnd,
        words: verified ?? _estimateWords(text, entry.start, safeEnd),
        confidence: .82,
        provenance: TimingProvenance.provider,
        vocalRole: entry.role,
      );
    });
  }

  List<LyricWord>? _parseWords(
    String source,
    Duration start,
    Duration end,
    Duration shift,
  ) {
    final tags = _wordTimestamp.allMatches(source).toList();
    if (tags.isEmpty ||
        source.substring(0, tags.first.start).trim().isNotEmpty) {
      return null;
    }
    final words = <LyricWord>[];
    var previous = start;
    for (var i = 0; i < tags.length; i++) {
      final onset = _parseTimestamp(tags[i]) + shift;
      if (onset < previous || onset < start || onset > end) return null;
      previous = onset;
      final text = source
          .substring(
            tags[i].end,
            i + 1 < tags.length ? tags[i + 1].start : source.length,
          )
          .trim();
      if (text.isEmpty) continue;
      final finish = i + 1 < tags.length
          ? _parseTimestamp(tags[i + 1]) + shift
          : end;
      if (finish <= onset || finish > end) return null;
      words.add(
        LyricWord(
          text: text,
          start: onset,
          end: finish,
          confidence: .94,
          provenance: TimingProvenance.provider,
        ),
      );
    }
    return words.isEmpty ? null : words;
  }

  List<LyricLine> estimatePlain(
    String source, {
    required Duration? trackDuration,
  }) {
    final texts = source
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (texts.isEmpty) return const [];
    final duration = trackDuration ?? Duration(seconds: texts.length * 5);
    final usableStart = Duration(
      milliseconds: (duration.inMilliseconds * .04).round(),
    );
    final usableMs = (duration.inMilliseconds * .92).round();
    final lineMs = (usableMs / texts.length).round().clamp(1200, 8000);
    return List.generate(texts.length, (index) {
      final start = usableStart + Duration(milliseconds: lineMs * index);
      final end = index == texts.length - 1
          ? duration
          : start + Duration(milliseconds: lineMs);
      return LyricLine(
        text: texts[index],
        start: start,
        end: end,
        words: _estimateWords(texts[index], start, end),
        confidence: .28,
        provenance: TimingProvenance.estimated,
      );
    });
  }

  Duration _parseTimestamp(RegExpMatch match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fraction = match.group(3) ?? '';
    final milliseconds = switch (fraction.length) {
      0 => 0,
      1 => int.parse(fraction) * 100,
      2 => int.parse(fraction) * 10,
      _ => int.parse(fraction.substring(0, 3)),
    };
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  List<LyricWord> _estimateWords(String text, Duration start, Duration end) {
    if (text.isEmpty) return const [];
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.length == 1) {
      return [
        LyricWord(
          text: text,
          start: start,
          end: end,
          confidence: .4,
          provenance: TimingProvenance.estimated,
        ),
      ];
    }
    final weights = tokens.map((token) {
      final punctuationPause = RegExp(r'[,.;:!?،。！？]$').hasMatch(token) ? 2 : 0;
      return token.runes.length.clamp(1, 10) + punctuationPause;
    }).toList();
    final total = weights.fold<int>(0, (sum, weight) => sum + weight);
    final spanUs = end.inMicroseconds - start.inMicroseconds;
    // A line timestamp usually marks the next line's onset, not the end of the
    // current vocal. Preserve a short hold instead of stretching the last words
    // through that gap, which otherwise creates visible cumulative lag.
    final tailHoldUs = (spanUs * .18).round().clamp(120000, 700000);
    final sungSpanUs = math.max(1, spanUs - tailHoldUs);
    var consumed = 0;
    return List.generate(tokens.length, (index) {
      final wordStart =
          start + Duration(microseconds: sungSpanUs * consumed ~/ total);
      consumed += weights[index];
      final wordEnd =
          start + Duration(microseconds: sungSpanUs * consumed ~/ total);
      return LyricWord(
        text: tokens[index],
        start: wordStart,
        end: wordEnd,
        confidence: .4,
        provenance: TimingProvenance.estimated,
      );
    });
  }
}
