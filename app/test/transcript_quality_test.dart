import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/learning/transcript_quality.dart';
import 'package:kinetic_lyrics/learning/on_device_recognition_worker.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';

void main() {
  test('silence and non-finite capture never enter transcription', () {
    expect(TranscriptQuality.hasSignal(Float32List(16000)), isFalse);
    expect(
      TranscriptQuality.hasSignal(Float32List.fromList([double.nan])),
      isFalse,
    );
    expect(
      TranscriptQuality.hasSignal(
        Float32List.fromList(List.filled(16000, .08)),
      ),
      isTrue,
    );
  });
  test(
    'obvious artifacts are rejected while short repeats and native text survive',
    () {
      for (final text in [
        '[Music]',
        '!!!',
        'Thank you for watching.',
        'ha ha ha ha ha ha ha ha ha',
      ]) {
        expect(
          TranscriptQuality.accepts(TranscriptQuality.clean(text)),
          isFalse,
        );
      }
      for (final text in [
        'oh oh oh',
        'ప్రేమ ప్రతి క్షణం',
        'காதல் நிலா',
        'प्यार की कहानी',
      ]) {
        expect(TranscriptQuality.accepts(text), isTrue);
      }
    },
  );
  test('BPE timestamps map to complete words, not the first N tokens', () {
    const result = RecognitionResult(
      text: 'Kinetic lyrics',
      tokens: [' Kin', 'etic', ' lyr', 'ics'],
      timestamps: [.2, .4, 1.2, 1.5],
    );
    final words = TranscriptQuality.timedWords(
      result,
      result.text,
      const Duration(seconds: 10),
      const Duration(seconds: 2),
    );
    expect(words.map((w) => w.text), ['Kinetic', 'lyrics']);
    expect(words.last.start, const Duration(milliseconds: 11200));
    expect(words.last.provenance, TimingProvenance.speechRecognition);
    expect(words.last.confidence, lessThan(.7));
  });
  test(
    'invalid, truncated and unreconstructable timing uses estimated provenance',
    () {
      for (final result in [
        const RecognitionResult(
          text: 'two words',
          tokens: ['wrong', ' tokens'],
          timestamps: [.1, .3],
        ),
        const RecognitionResult(
          text: 'two words',
          tokens: ['two', ' words'],
          timestamps: [1.5, .2],
        ),
        const RecognitionResult(
          text: 'two words',
          tokens: ['two', ' words'],
          timestamps: [.1, 8],
        ),
        const RecognitionResult(
          text: 'ప్రేమ నీతో',
          tokens: ['ప్రే', 'మ', ' నీతో'],
          timestamps: [.1],
        ),
      ]) {
        final words = TranscriptQuality.timedWords(
          result,
          result.text,
          Duration.zero,
          const Duration(seconds: 2),
        );
        expect(
          words.every((w) => w.provenance == TimingProvenance.estimated),
          isTrue,
        );
        expect(words.last.end, const Duration(seconds: 2));
        expect(words.first.start, Duration.zero);
      }
    },
  );
}
