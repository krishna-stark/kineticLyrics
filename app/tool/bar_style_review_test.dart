import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/visuals/spectrum_bars.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'export solid and outline bars with identical measured-band fixtures',
    () async {
      await (FontLoader(
        'SpaceGrotesk',
      )..addFont(rootBundle.load('assets/fonts/SpaceGrotesk.ttf'))).load();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      for (var i = 0; i < 2; i++) {
        final bars = SpectrumBars(outlined: i == 1);
        final label = TextPainter(
          text: TextSpan(
            text: i == 0 ? 'SOLID' : 'OUTLINE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(24 + i * 480, 16));
        label.dispose();
        canvas.save();
        canvas.translate(20 + i * 480, 50);
        for (var frame = 0; frame < 20; frame++) {
          // Clip each earlier frame out of the output while updating real smoothing.
          canvas.save();
          if (frame < 19) canvas.clipRect(Rect.zero);
          bars.paint(
            canvas,
            const Size(440, 310),
            AudioFeatures(
              live: true,
              energy: .5,
              spectrum: List.generate(
                32,
                (n) => .08 + .48 * math.sin(n * .55).abs(),
              ),
            ),
            frame / 60,
            takeover: 1,
          );
          canvas.restore();
        }
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(960, 380);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/review').create(recursive: true);
      await File(
        'build/review/bar-style-comparison.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    },
  );
}
