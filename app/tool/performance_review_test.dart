import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';
import 'package:kinetic_lyrics/visuals/instrumental_field.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_performance.dart';
import 'package:kinetic_lyrics/visuals/performance_settings.dart';
import 'package:kinetic_lyrics/visuals/song_score.dart';
import 'package:kinetic_lyrics/visuals/spectrum_bars.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'render three musical directions with actual fonts and shared production renderer',
    () async {
      for (final family in [
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
      ]) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
      }
      await (FontLoader(
        'LyricDisplay',
      )..addFont(rootBundle.load('assets/fonts/LyricDisplay-Bold.ttf'))).load();
      final examples = [
        (
          'Intimate melody',
          [
            'Love in the moonlight',
            'Stay a little closer',
            'The night belongs to us',
            'Stay a little closer',
            'The night belongs to us',
          ],
        ),
        (
          'Fast delivery',
          [
            'Find our rhythm carry it forward',
            'Move with the music into the night',
            'Find our rhythm carry it forward',
            'Move with the music into the night',
          ],
        ),
        (
          'Native-script refrain',
          [
            'ప్రేమ ప్రతి క్షణం నీతో',
            'కన్నుల్లో నక్షత్రాలు మెరిసే',
            'నీతో నా ప్రయాణం',
            'కన్నుల్లో నక్షత్రాలు మెరిసే',
            'నీతో నా ప్రయాణం',
          ],
        ),
      ];
      final contactImages = <ui.Image>[];
      final contact = ui.PictureRecorder();
      final contactCanvas = Canvas(contact)
        ..drawColor(Colors.black, BlendMode.src);
      const size = Size(384, 832);
      for (var c = 0; c < examples.length; c++) {
        final fixture = examples[c];
        final lineSpan = c == 1 ? 1700 : 5000;
        final timeline = LyricTimeline(
          provider: 'review-fixture',
          quality: LyricsTimingQuality.wordSynced,
          lines: [
            for (var i = 0; i < fixture.$2.length; i++)
              _line(fixture.$2[i], i * lineSpan, lineSpan),
          ],
        );
        final score = SongScore.prepare(timeline, identity: fixture.$1);
        for (var phase = 0; phase < 2; phase++) {
          final scene = score.scenes[phase == 0 ? 0 : 2];
          final composition = LyricComposition.prepare(
            scene,
            const Size(306, 350),
            TextDirection.ltr,
          );
          for (final word in composition.shots.expand((s) => s.words)) {
            await word.rasterize(2);
          }
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawColor(Colors.black, BlendMode.src);
          final object = score.objects[scene.index];
          if (object != null) {
            ContextAssetStore.paint(
              canvas,
              object,
              const Offset(276, 191),
              84,
              .18,
            );
          }
          final age = c == 1 ? 460 : 1450;
          final position = scene.line.start + Duration(milliseconds: age);
          LyricPerformance.paint(
            canvas,
            size,
            scene,
            composition,
            position,
            settings: const PerformanceSettings(),
            bassHit: .65,
            midHit: .4,
          );
          final spectrum = List<double>.generate(
            32,
            (i) =>
                (math.sin(i * .72 + c).abs() * .45 + .12) * (c == 0 ? .62 : 1),
          );
          final audio = AudioFeatures(
            live: true,
            spectrum: spectrum,
            bass: .7,
            mid: .5,
            treble: .6,
            bassOnset: .65,
            midOnset: .4,
            trebleOnset: .7,
          );
          final field = SpectrumBars();
          for (var tick = 0; tick < 60; tick++) {
            canvas.drawRect(
              Rect.fromLTWH(
                0,
                size.height * 2 / 3,
                size.width,
                size.height / 3,
              ),
              Paint()..color = Colors.black,
            );
            field.paint(canvas, size, audio, tick / 60, takeover: 0);
          }
          _label(canvas, '18:42', const Offset(24, 32));
          final label = TextPainter(
            text: TextSpan(
              text: fixture.$1,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 240);
          label.paint(canvas, Offset(size.width - 24 - label.width, 32));
          label.dispose();
          _label(
            canvas,
            'PREPARED FIXTURE · ${phase == 0 ? 'VERSE' : 'REFRAIN'}',
            const Offset(24, 500),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(384, 832);
          picture.dispose();
          contactCanvas.drawImage(
            image,
            Offset(c * 384.0, phase * 832.0),
            Paint(),
          );
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/review/performance-$c-$phase.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          contactImages.add(image);
          composition.dispose();
        }
      }
      final picture = contact.endRecording();
      final image = await picture.toImage(1152, 1664);
      picture.dispose();
      await File('build/review/performance-contact.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();
      for (final retained in contactImages) {
        retained.dispose();
      }
      for (final style in [
        InstrumentalStyle.waveform,
        InstrumentalStyle.contour,
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
        final wave = List<double>.generate(
          64,
          (i) => math.sin(i * .29) * math.sin(i * .061),
        );
        InstrumentalField.paint(
          canvas,
          size,
          AudioFeatures(live: true, waveform: wave, mid: .6, trebleOnset: .5),
          reveal: 1,
          style: style,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(384, 832);
        picture.dispose();
        await File('build/review/instrumental-${style.name}.png').writeAsBytes(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
        image.dispose();
      }
    },
  );
}

LyricLine _line(String text, int start, int span) {
  final tokens = text.split(' ');
  return LyricLine(
    text: text,
    start: Duration(milliseconds: start),
    end: Duration(milliseconds: start + span),
    provenance: TimingProvenance.provider,
    confidence: .94,
    words: [
      for (var i = 0; i < tokens.length; i++)
        LyricWord(
          text: tokens[i],
          start: Duration(milliseconds: start + span * i ~/ tokens.length),
          end: Duration(milliseconds: start + span * (i + 1) ~/ tokens.length),
          confidence: .94,
          provenance: TimingProvenance.provider,
          stress: i == 0 ? .8 : .2,
        ),
    ],
  );
}

void _label(Canvas canvas, String text, Offset offset) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 12,
        color: Colors.white38,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
  painter.dispose();
}
