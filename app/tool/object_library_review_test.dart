import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('review prepared contextual object artwork at production opacity', () async {
    await (FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk.ttf'))).load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
    const ids = ['guitar', 'umbrella', 'candle', 'feather', 'desert', 'dancer', 'rose', 'moon', 'butterfly'];
    for (var index = 0; index < ids.length; index++) {
      final x = (index % 3) * 240.0;
      final y = (index ~/ 3) * 260.0;
      ContextAssetStore.paint(canvas, ids[index], Offset(x + 120, y + 120), 82, .30, time: 2, energy: .5);
      final caption = TextPainter(textDirection: TextDirection.ltr, text: TextSpan(
        text: ids[index], style: const TextStyle(fontFamily: 'SpaceGrotesk', color: Colors.white54, fontSize: 16)))..layout();
      caption.paint(canvas, Offset(x + 120 - caption.width / 2, y + 220));
      caption.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(720, 780);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/review/contextual-objects.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose(); picture.dispose();
  });
}
