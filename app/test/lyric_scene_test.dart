import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final text in [
    'This is a long English lyric that needs room to breathe and still remain readable',
    'నీ ప్రేమలో ప్రతి క్షణం నా మనసులో నిలిచే అందమైన జ్ఞాపకం',
    'உன் காதலில் ஒவ்வொரு நொடியும் என் இதயத்தில் இனிய நினைவாக நிற்கிறது',
    'ప్రేమ love காதல் together మనసులో forever',
    'supercalifragilisticexpialidocioussupercalifragilisticexpialidocious',
  ]) {
    test(
      'empty timestamped intervals remain available for instrumental takeover',
      () {
        const timeline = LyricTimeline(
          provider: 'test',
          quality: LyricsTimingQuality.lineSynced,
          lines: [
            LyricLine(
              text: 'Stay',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
            LyricLine(
              text: '',
              start: Duration(seconds: 1),
              end: Duration(seconds: 2),
            ),
            LyricLine(
              text: 'with me',
              start: Duration(seconds: 2),
              end: Duration(seconds: 3),
            ),
          ],
        );
        final prepared = LyricScene.prepare(
          LyricScene.readableTimeline(timeline),
        );
        expect(prepared.length, 3);
        expect(prepared[1].hasLyrics, isFalse);
        expect(prepared[0].hasLyrics, isTrue);
        expect(prepared[2].hasLyrics, isTrue);
      },
    );
    test('fits whole words in two lines: $text', () {
      final shape = ShapedPhrase.fit(
        LyricLine(
          text: text,
          start: Duration.zero,
          end: const Duration(seconds: 4),
        ),
        const Size(270, 400),
        TextDirection.ltr,
      );
      expect(shape.size.width, lessThanOrEqualTo(270.1));
      expect(shape.size.height, lessThanOrEqualTo(400.1));
      expect(shape.painter.computeLineMetrics().length, lessThanOrEqualTo(2));
      final shaped = shape.painter.text!.toPlainText();
      expect(shaped.replaceAll('\n', ' '), text);
      shape.dispose();
    });
  }
  test(
    'fast adjacent lines are grouped before entrance, gaps stay instrumental',
    () {
      final result = LyricScene.readableTimeline(
        const LyricTimeline(
          provider: 'test',
          quality: LyricsTimingQuality.lineSynced,
          lines: [
            LyricLine(
              text: 'one two',
              start: Duration.zero,
              end: Duration(milliseconds: 400),
            ),
            LyricLine(
              text: 'three four',
              start: Duration(milliseconds: 400),
              end: Duration(milliseconds: 800),
            ),
            LyricLine(
              text: 'five six',
              start: Duration(milliseconds: 800),
              end: Duration(milliseconds: 1200),
            ),
            LyricLine(
              text: 'after a gap',
              start: Duration(seconds: 6),
              end: Duration(seconds: 8),
            ),
          ],
        ),
      );
      expect(result.lines.first.text, 'one two three four five six');
      expect(result.lines.first.words.length, 6);
      expect(result.lines.first.end, const Duration(milliseconds: 1200));
      expect(result.lines.length, 2);
    },
  );
  test(
    'repeated lyrics reuse a motif and multilingual meaning is recognized',
    () {
      const timeline = LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.lineSynced,
        lines: [
          LyricLine(
            text: 'my love',
            start: Duration.zero,
            end: Duration(seconds: 4),
          ),
          LyricLine(
            text: 'alone in rain',
            start: Duration(seconds: 4),
            end: Duration(seconds: 8),
          ),
          LyricLine(
            text: 'my love',
            start: Duration(seconds: 8),
            end: Duration(seconds: 12),
          ),
        ],
      );
      final scenes = LyricScene.prepare(timeline);
      expect(scenes[0].motif, scenes[2].motif);
      expect(scenes[0].mood, LyricMood.romantic);
      expect(scenes[1].mood, LyricMood.lonely);
      expect(LyricScene.moodFor('నీ ప్రేమ మనసులో'), LyricMood.romantic);
      expect(LyricScene.moodFor('உன் காதல்'), LyricMood.romantic);
    },
  );
}
