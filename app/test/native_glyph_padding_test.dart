import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native marks survive glyph caching and fades in six bundled fonts',
    () async {
      final recorder = ui.PictureRecorder();
      final preview = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      var row = 0;
      final words = <ComposedWord>[];
      for (final script in [
        ('Telugu', 'ప్రేమించే'),
        ('Tamil', 'நீங்காத'),
        ('Devanagari', 'ज़िंदगी'),
      ]) {
        for (final variant in ['Sans', 'Serif']) {
          final family = 'Noto$variant${script.$1}';
          await (FontLoader(
            family,
          )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
          final painter = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: script.$2,
              style: TextStyle(
                fontFamily: family,
                fontSize: 64,
                color: Colors.white,
              ),
            ),
          )..layout();
          final word = ComposedWord(
            LyricWord(
              text: script.$2,
              start: Duration.zero,
              end: const Duration(seconds: 4),
            ),
            painter,
            const Offset(60, 60),
            true,
            0,
          );
          Future<({int coverage, int top, int bottom})> pixels({
            required bool cached,
          }) async {
            if (cached) await word.rasterize(1);
            final r = ui.PictureRecorder();
            final c = Canvas(r);
            word.paint(c, .65);
            final p = r.endRecording();
            final image = await p.toImage(500, 230);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var count = 0;
            var top = 230;
            var bottom = 0;
            for (var i = 3; i < bytes.length; i += 4) {
              count += bytes[i];
              if (bytes[i] > 25) {
                final y = (i ~/ 4) ~/ 500;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
            }
            image.dispose();
            p.dispose();
            return (coverage: count, top: top, bottom: bottom);
          }

          final direct = await pixels(cached: false);
          final cached = await pixels(cached: true);
          expect(
            cached.coverage,
            closeTo(direct.coverage, direct.coverage * .035),
            reason: '$family loses glyph pixels',
          );
          expect(
            cached.top,
            closeTo(direct.top, 2),
            reason: '$family top marks clipped',
          );
          expect(
            cached.bottom,
            closeTo(direct.bottom, 2),
            reason: '$family lower marks clipped',
          );
          preview.save();
          preview.translate(0, row * 145.0);
          word.paint(preview, 1);
          preview.restore();
          row++;
          words.add(word);
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(500, 900);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/review/native-glyph-padding.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      for (final word in words) {
        word.dispose();
      }
    },
  );
}
