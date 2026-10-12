import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cached plain glyphs retain fade opacity and tolerate disposal during preparation',
    () async {
      final line = const LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.lineSynced,
        lines: [
          LyricLine(
            text: 'Hold the line',
            start: Duration.zero,
            end: Duration(seconds: 4),
          ),
        ],
      ).enrich().lines.first;
      final scene = LyricScene(line, 0, LyricMood.quiet, 0);
      final composition = LyricComposition.prepare(
        scene,
        const Size(300, 350),
        TextDirection.ltr,
      );
      final word = composition.shots.first.words.first;
      await word.rasterize(2);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawColor(Colors.black, BlendMode.src)
        ..translate(200, 200);
      word.paint(canvas, .4);
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      picture.dispose();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var brightest = 0;
      for (var p = 0; p < bytes.length; p += 4) {
        if (bytes[p] > brightest) brightest = bytes[p];
        expect(bytes[p], bytes[p + 1]);
      }
      expect(brightest, inInclusiveRange(100, 103));
      image.dispose();
      composition.dispose();
      final cancelled = LyricComposition.prepare(
        scene,
        const Size(300, 350),
        TextDirection.ltr,
      );
      final pending = cancelled.shots.first.words.first.rasterize(2);
      cancelled.dispose();
      await pending;
    },
  );
  test('semantic direction changes prepared font and transition', () {
    final line = const LyricTimeline(
      provider: 'test',
      quality: LyricsTimingQuality.lineSynced,
      lines: [
        LyricLine(
          text: 'Call me tonight',
          start: Duration.zero,
          end: Duration(seconds: 5),
        ),
      ],
    ).enrich().lines.first;
    final scene = LyricScene(line, 0, LyricMood.quiet, 0);
    const semantic = LineSemanticProfile(
      lineIndex: 0,
      motionPath: SemanticMotionPath.split,
      motionConfidence: .9,
    );
    final composition = LyricComposition.prepare(
      scene,
      const Size(300, 350),
      TextDirection.ltr,
      semantic: semantic,
    );
    expect(LyricComposition.fontFor(scene, semantic), 'CormorantGaramond');
    expect(
      composition.shots.first.words
          .firstWhere((w) => w.hero)
          .painter
          .text!
          .style!
          .fontFamily,
      'CormorantGaramond',
    );
    expect(composition.shots.first.transition, SemanticTransition.lift);
    composition.dispose();
  });
  test(
    'long phrases become sequential composed shots without losing words',
    () {
      final line = const LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.lineSynced,
        lines: [
          LyricLine(
            text: 'We find our rhythm in the light and carry it home tonight',
            start: Duration.zero,
            end: Duration(seconds: 8),
          ),
        ],
      ).enrich().lines.first;
      final composition = LyricComposition.prepare(
        LyricScene(line, 0, LyricMood.joyful, 0),
        const Size(300, 440),
        TextDirection.ltr,
      );
      expect(composition.shots.length, greaterThan(2));
      expect(composition.shots.first.words.length, 4);
      expect(
        composition.shots
            .expand((s) => s.words)
            .map((w) => w.word.text)
            .join(' '),
        line.text,
      );
      for (var ms = 0; ms < 8000; ms += 20) {
        final position = Duration(milliseconds: ms);
        final shot = composition.at(position)!;
        final active = line.wordAt(position);
        if (active != null) {
          expect(shot.words.any((w) => w.word.id == active.id), isTrue);
        }
      }
      expect(composition.at(const Duration(seconds: 8)), isNull);
      composition.dispose();
    },
  );
  test(
    'all scene families fit complete multilingual words in prepared slots',
    () {
      for (final width in [256.0, 300.0, 390.0]) {
        for (final text in [
          'ప్రేమ మనసులో ప్రతి క్షణం నీతో',
          'காதல் நம்மை வானத்தில் அழைக்கிறது',
          'extraordinarily beautiful rhythm through the night',
          'నీతో every beat காதல் tonight',
        ]) {
          final line = LyricTimeline(
            provider: 'test',
            quality: LyricsTimingQuality.estimated,
            lines: [
              LyricLine(
                text: text,
                start: Duration.zero,
                end: const Duration(seconds: 6),
              ),
            ],
          ).enrich().lines.first;
          for (var index = 0; index < 6; index++) {
            final composition = LyricComposition.prepare(
              LyricScene(
                line,
                index,
                index == 5 ? LyricMood.lonely : LyricMood.joyful,
                0,
                refrain: index == 4,
              ),
              Size(width, 440),
              TextDirection.ltr,
            );
            for (final shot in composition.shots) {
              for (final word in shot.words) {
                expect(word.painter.computeLineMetrics().length, 1);
                expect(word.bounds.left, greaterThanOrEqualTo(-width / 2));
                expect(word.bounds.right, lessThanOrEqualTo(width / 2));
                expect(word.bounds.top, greaterThanOrEqualTo(-220));
                expect(word.bounds.bottom, lessThanOrEqualTo(220));
              }
            }
            composition.dispose();
          }
        }
      }
    },
  );
}
