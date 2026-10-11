import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/visuals/spectrum_bars.dart';

Future<ui.Image> render(
  SpectrumBars bars,
  AudioFeatures audio,
  double time, {
  double takeover = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
  bars.paint(canvas, const Size(384, 832), audio, time, takeover: takeover);
  final picture = recorder.endRecording();
  final image = await picture.toImage(384, 832);
  picture.dispose();
  return image;
}

Future<List<int>> pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List().toList();
}

AudioFeatures fixture({bool beat = false, int frame = 0}) => AudioFeatures(
  live: true,
  energy: .65,
  bass: .6,
  mid: .7,
  treble: .5,
  bassOnset: beat ? .8 : .1,
  trebleOnset: beat ? .7 : .1,
  timestamp: Duration(milliseconds: frame * 33),
  spectrum: List.generate(
    32,
    (i) => .08 + .45 * math.sin(i * .57 + frame * .14).abs(),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'short bars stay white; tall bars reveal red only above the height threshold',
    () async {
      final bars = SpectrumBars();
      final audio = AudioFeatures(
        live: true,
        energy: .5,
        spectrum: List.filled(32, .12),
      );
      List<int> low = [];
      for (var i = 0; i < 10; i++) {
        low = await pixels(await render(bars, audio, i / 30));
      }
      var lowLit = 0;
      for (var p = 0; p < low.length; p += 4) {
        expect(low[p], low[p + 1]);
        if (low[p] > 80) lowLit++;
      }
      expect(lowLit, greaterThan(1000));
      final highAudio = AudioFeatures(
        live: true,
        energy: .5,
        spectrum: List.filled(32, .65),
      );
      List<int> high = [];
      for (var i = 10; i < 30; i++) {
        high = await pixels(await render(bars, highAudio, i / 30));
      }
      var red = 0, neutral = 0;
      for (var y = 0; y < 832; y++) {
        final p = (y * 384 + 2) * 4;
        if (high[p] > 80 && high[p] > high[p + 1] * 1.5) {
          red++;
          expect(y, lessThan(675));
        }
        if (high[p] > 80 && high[p] == high[p + 1]) neutral++;
      }
      expect(red, greaterThan(20));
      expect(neutral, greaterThan(50));
      if (const bool.fromEnvironment('VISUAL_REVIEW')) {
        final image = await render(bars, highAudio, 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/review').create(recursive: true);
        await File(
          'build/review/height-gradient.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      }
    },
  );
  test(
    'spectrum changes, paused frames hold and silence releases to black',
    () async {
      final bars = SpectrumBars();
      final first = await pixels(await render(bars, fixture(), 0));
      final paused = await pixels(await render(bars, fixture(frame: 5), 0));
      expect(paused, first);
      final moved = await pixels(await render(bars, fixture(frame: 5), .2));
      expect(moved, isNot(equals(first)));
      List<int> silent = [];
      for (var i = 1; i <= 60; i++) {
        silent = await pixels(
          await render(bars, AudioFeatures.silent, .2 + i / 30),
        );
      }
      for (var i = 0; i < silent.length; i += 4) {
        expect(silent.sublist(i, i + 3), [0, 0, 0]);
      }
      bars.reset();
      final full = await pixels(await render(bars, fixture(), 1, takeover: 1));
      var above = 0;
      for (var y = 0; y < 554; y++) {
        for (var x = 0; x < 384; x++) {
          if (full[(y * 384 + x) * 4] > 50) above++;
        }
      }
      expect(above, greaterThan(100));
    },
  );
  test('export melody and beat fixtures for reference review', () async {
    if (!const bool.fromEnvironment('VISUAL_REVIEW')) return;
    for (final beat in [false, true]) {
      final bars = SpectrumBars();
      final dir = Directory(
        'build/review/reference-${beat ? 'beat' : 'melody'}',
      )..createSync(recursive: true);
      for (var i = 0; i < 60; i++) {
        final image = await render(bars, fixture(beat: beat, frame: i), i / 30);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(
          '${dir.path}/${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      }
    }
  });
}
