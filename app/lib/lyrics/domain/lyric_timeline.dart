import 'package:characters/characters.dart';

enum LyricsTimingQuality { wordSynced, lineSynced, estimated, unsynced }

enum TimingProvenance {
  provider,
  forcedAlignment,
  speechRecognition,
  estimated,
}

enum VocalRole { lead, response, backing, together }

class LyricGrapheme {
  const LyricGrapheme({
    required this.text,
    required this.start,
    required this.end,
    required this.clusterIndex,
    this.confidence = .5,
  });

  final String text;
  final Duration start;
  final Duration end;
  final int clusterIndex;
  final double confidence;
}

class LyricSyllable {
  const LyricSyllable({
    required this.text,
    required this.start,
    required this.end,
    this.stress = 0,
    this.confidence = .4,
    this.graphemes = const [],
  });

  final String text;
  final Duration start;
  final Duration end;
  final double stress;
  final double confidence;
  final List<LyricGrapheme> graphemes;
}

class LyricWord {
  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
    this.id = '',
    this.confidence = .5,
    this.provenance = TimingProvenance.estimated,
    this.stress = 0,
    this.pitch = 0,
    this.syllables = const [],
    this.graphemes = const [],
  });

  final String text;
  final Duration start;
  final Duration end;
  final String id;
  final double confidence;
  final TimingProvenance provenance;
  final double stress;
  final double pitch;
  final List<LyricSyllable> syllables;
  final List<LyricGrapheme> graphemes;

  double progressAt(Duration position) => _progress(position, start, end);
}

class LyricLine {
  const LyricLine({
    required this.text,
    required this.start,
    required this.end,
    this.words = const [],
    this.id = '',
    this.confidence = .5,
    this.provenance = TimingProvenance.estimated,
    this.vocalRole = VocalRole.lead,
  });

  final String text;
  final Duration start;
  final Duration end;
  final List<LyricWord> words;
  final String id;
  final double confidence;
  final TimingProvenance provenance;
  final VocalRole vocalRole;

  double progressAt(Duration position) => _progress(position, start, end);

  LyricWord? wordAt(Duration position) {
    if (words.isEmpty) return null;
    var low = 0;
    var high = words.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final word = words[middle];
      if (position < word.start) {
        high = middle - 1;
      } else if (position >= word.end) {
        low = middle + 1;
      } else {
        return word;
      }
    }
    return null;
  }
}

class LyricTimeline {
  const LyricTimeline({
    required this.provider,
    required this.quality,
    required this.lines,
  });

  final String provider;
  final LyricsTimingQuality quality;
  final List<LyricLine> lines;

  int indexAt(Duration position) {
    if (lines.isEmpty || position < lines.first.start) return -1;
    var low = 0;
    var high = lines.length - 1;
    var result = 0;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (lines[middle].start <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }

  LyricLine? lineAt(Duration position) {
    final index = indexAt(position);
    return index < 0 ? null : lines[index];
  }

  /// Adds stable IDs and Unicode extended-grapheme timing without ever
  /// splitting a combining sequence or Indic conjunct by code point.
  LyricTimeline enrich() => LyricTimeline(
    provider: provider,
    quality: quality,
    lines: [
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++)
        _enrichLine(lines[lineIndex], lineIndex),
    ],
  );

  LyricLine _enrichLine(LyricLine line, int lineIndex) {
    final words = line.words.isEmpty
        ? _estimateWords(line.text, line.start, line.end)
        : line.words;
    return LyricLine(
      id: line.id.isEmpty ? 'line-$lineIndex' : line.id,
      text: line.text,
      start: line.start,
      end: line.end,
      confidence: line.confidence,
      provenance: line.provenance,
      vocalRole: line.vocalRole,
      words: [
        for (var wordIndex = 0; wordIndex < words.length; wordIndex++)
          _enrichWord(words[wordIndex], lineIndex, wordIndex),
      ],
    );
  }

  LyricWord _enrichWord(LyricWord word, int lineIndex, int wordIndex) {
    final clusters = word.text.characters.toList(growable: false);
    final span = word.end.inMicroseconds - word.start.inMicroseconds;
    final graphemes = word.graphemes.isNotEmpty
        ? word.graphemes
        : [
            for (var index = 0; index < clusters.length; index++)
              LyricGrapheme(
                text: clusters[index],
                start:
                    word.start +
                    Duration(microseconds: span * index ~/ clusters.length),
                end:
                    word.start +
                    Duration(
                      microseconds: span * (index + 1) ~/ clusters.length,
                    ),
                clusterIndex: index,
                confidence: word.confidence * .8,
              ),
          ];
    return LyricWord(
      id: word.id.isEmpty ? 'line-$lineIndex-word-$wordIndex' : word.id,
      text: word.text,
      start: word.start,
      end: word.end,
      confidence: word.confidence,
      provenance: word.provenance,
      stress: word.stress,
      pitch: word.pitch,
      syllables: word.syllables,
      graphemes: graphemes,
    );
  }

  List<LyricWord> _estimateWords(String text, Duration start, Duration end) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || (tokens.length == 1 && tokens.first.isEmpty)) {
      return const [];
    }
    final total = tokens.fold<int>(
      0,
      (sum, token) => sum + token.characters.length.clamp(1, 12),
    );
    final span = end.inMicroseconds - start.inMicroseconds;
    var consumed = 0;
    return [
      for (final token in tokens)
        LyricWord(
          text: token,
          start: start + Duration(microseconds: span * consumed ~/ total),
          end:
              start +
              Duration(
                microseconds:
                    span *
                    (consumed += token.characters.length.clamp(1, 12)) ~/
                    total,
              ),
        ),
    ];
  }
}

double _progress(Duration value, Duration start, Duration end) {
  final span = end.inMicroseconds - start.inMicroseconds;
  if (span <= 0) return 1;
  return ((value.inMicroseconds - start.inMicroseconds) / span).clamp(0, 1);
}
