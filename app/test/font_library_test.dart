import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/plain_type.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';

const families = [
  'BebasNeue',
  'CormorantGaramond',
  'SpaceGrotesk',
  'Anton',
  'Oswald',
  'PlayfairDisplay',
  'DMSerifDisplay',
  'BodoniModa',
  'DancingScript',
  'Cinzel',
  'BlackOpsOne',
  'NotoSansTelugu',
  'NotoSerifTelugu',
  'NotoSansTamil',
  'NotoSerifTamil',
  'NotoSansDevanagari',
  'NotoSerifDevanagari',
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in families) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });
  test(
    'native scripts choose bundled sans or serif rather than Latin fallback',
    () {
      for (final entry in {
        'ప్రేమ': 'Telugu',
        'காதல்': 'Tamil',
        'प्यार': 'Devanagari',
      }.entries) {
        final line = LyricLine(
          text: entry.key,
          start: Duration.zero,
          end: const Duration(seconds: 4),
        );
        expect(
          LyricComposition.fontFor(LyricScene(line, 0, LyricMood.heavy, 0)),
          'NotoSans${entry.value}',
        );
        expect(
          LyricComposition.fontFor(LyricScene(line, 0, LyricMood.romantic, 0)),
          'NotoSerif${entry.value}',
        );
      }
    },
  );
  test(
    'hero and supporting fonts contrast without leaving the native script',
    () {
      for (final text in [
        'Feel the music',
        'ప్రేమ నీతో',
        'காதல் நிலா',
        'प्यार की कहानी',
      ]) {
        final line = LyricLine(
          text: text,
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        final scene = LyricScene(
          line,
          0,
          LyricMood.romantic,
          0,
          directed: true,
          fontSeed: 2,
        );
        final hero = LyricComposition.fontFor(scene);
        final support = LyricComposition.supportFontFor(scene);
        expect(support, isNot(hero));
        for (final script in ['Telugu', 'Tamil', 'Devanagari']) {
          if (hero.contains(script)) expect(support, contains(script));
        }
        final composition = LyricComposition.prepare(
          LyricScene(
            LyricTimeline(
              provider: 'test',
              quality: LyricsTimingQuality.lineSynced,
              lines: [line],
            ).enrich().lines.first,
            0,
            LyricMood.romantic,
            0,
            directed: true,
            fontSeed: 2,
          ),
          const Size(270, 280),
          TextDirection.ltr,
        );
        final shot = composition.shots.first;
        expect(
          shot.words.firstWhere((w) => w.hero).painter.text!.style!.fontFamily,
          hero,
        );
        expect(
          shot.words
              .where((w) => !w.hero)
              .every((w) => w.painter.text!.style!.fontFamily == support),
          isTrue,
        );
        composition.dispose();
      }
    },
  );
  test('expanded fonts render distinct plain white glyphs', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.black, BlendMode.src);
    for (var i = 0; i < families.length; i++) {
      final family = families[i];
      final text = family.contains('Telugu')
          ? 'ప్రేమ వెలుగు'
          : family.contains('Tamil')
          ? 'காதல் நிலா'
          : family.contains('Devanagari')
          ? 'प्यार की रोशनी'
          : 'FEEL THE MUSIC';
      final label = TextPainter(
        text: TextSpan(
          text: family,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(24, i * 100 + 8));
      label.dispose();
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: family,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 670);
      final origin = Offset(24, i * 100 + 30);
      PlainType.paint(canvas, painter, origin, origin & painter.size);
      painter.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(720, 1700);
    picture.dispose();
    final raw = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var lit = 0;
    for (var p = 0; p < raw.length; p += 4) {
      if (raw[p] > 80) lit++;
      // Plain white lettering has no color filter or material tint.
      expect(raw[p], lessThanOrEqualTo(raw[p + 2] + 1));
    }
    expect(lit, greaterThan(20000));
    if (const bool.fromEnvironment('VISUAL_REVIEW')) {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        'build/review/font-plain-review.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
    image.dispose();
  });
}
