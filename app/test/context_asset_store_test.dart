import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every AI object has visible prepared artwork', () async {
    for (final kind in BackgroundObjectKind.values) {
      expect(ContextAssetStore.availableIds, contains(kind.name));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      ContextAssetStore.paint(canvas, kind.name, const Offset(60, 60), 40, .3);
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 120);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var visible = 0;
      for (var i = 0; i < data.length; i += 4) {
        if (data[i] + data[i + 1] + data[i + 2] > 10) visible++;
      }
      expect(visible, greaterThan(20), reason: kind.name);
      image.dispose();
      picture.dispose();
    }
  });
}
