import 'dart:math' as math;
import 'dart:typed_data';
import '../lyrics/domain/lyric_timeline.dart';
import 'on_device_recognition_worker.dart';

/// Conservative sanity checks, not a claim that recognized lyrics are correct.
class TranscriptQuality {
  static bool hasSignal(Float32List samples) {
    if (samples.isEmpty) return false;
    var energy = 0.0;
    var peak = 0.0;
    for (final sample in samples) {
      if (!sample.isFinite) return false;
      energy += sample * sample;
      peak = math.max(peak, sample.abs());
    }
    return math.sqrt(energy / samples.length) >= .001 && peak >= .004;
  }

  static String clean(String value) => value
      .replaceAll(RegExp(r'\[[^\]]+\]|<\|[^|]+\|>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool accepts(String value) {
    if (value.isEmpty ||
        !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value)) {
      return false;
    }
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();
    if (const {
      'thank you for watching',
      'thanks for watching',
      'subtitles by amaraorg',
      'subscribe to my channel',
    }.contains(normalized)) {
      return false;
    }
    final words = normalized.split(RegExp(r'\s+'));
    if (words.length < 8) return true;
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }
    return counts.values.reduce(math.max) / words.length <= .75;
  }

  /// Timestamps belong to BPE tokens, not whitespace-separated words. Only
  /// align them when complete token text exactly reconstructs the transcript.
  /// Missing/invalid mappings retain explicit estimated timing.
  static List<LyricWord> timedWords(
    RecognitionResult result,
    String text,
    Duration offset,
    Duration duration,
  ) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || duration <= Duration.zero) return const [];
    final joined = result.tokens.join();
    final matches = RegExp(r'\S+').allMatches(joined).toList();
    var valid =
        result.tokens.length == result.timestamps.length &&
        result.tokens.isNotEmpty &&
        clean(joined) == text &&
        !joined.contains('\uFFFD') &&
        matches.length == words.length;
    var previous = -1.0;
    for (final timestamp in result.timestamps) {
      if (!timestamp.isFinite ||
          timestamp < previous ||
          timestamp < 0 ||
          timestamp * 1000 >= duration.inMilliseconds) {
        valid = false;
      }
      previous = timestamp;
    }
    final starts = <Duration>[];
    if (valid) {
      var cursor = 0;
      var token = 0;
      for (final match in matches) {
        while (token < result.tokens.length - 1 &&
            cursor + result.tokens[token].length <= match.start) {
          cursor += result.tokens[token++].length;
        }
        starts.add(
          Duration(milliseconds: (result.timestamps[token] * 1000).round()),
        );
      }
      if (starts.toSet().length != starts.length) valid = false;
    }
    return [
      for (var i = 0; i < words.length; i++)
        LyricWord(
          text: words[i],
          start:
              offset +
              (valid
                  ? starts[i]
                  : Duration(
                      microseconds: duration.inMicroseconds * i ~/ words.length,
                    )),
          end:
              offset +
              (valid && i + 1 < words.length
                  ? starts[i + 1]
                  : valid
                  ? duration
                  : Duration(
                      microseconds:
                          duration.inMicroseconds * (i + 1) ~/ words.length,
                    )),
          confidence: valid ? .6 : .4,
          provenance: valid
              ? TimingProvenance.speechRecognition
              : TimingProvenance.estimated,
        ),
    ];
  }
}
