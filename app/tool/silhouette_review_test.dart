// Run: flutter test tool/silhouette_review_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';

void main() {
  test('export prepared reference silhouettes at playback opacity', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
    for (var i = 0; i < 3; i++) {
      ContextAssetStore.paint(
        canvas,
        ['raisedFist', 'heart', 'flame'][i],
        Offset(160 + i * 320, 170),
        115,
        .20,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 340);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/review').create(recursive: true);
    await File(
      'build/review/song-silhouettes.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
