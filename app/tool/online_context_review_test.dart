// Real-network review: flutter test tool/online_context_review_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/semantics/online_song_context.dart';

class RealNetwork extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real generic lookup returns and renders a licensed transparent artist silhouette',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final store = OnlineSongContextStore(
          cacheDirectory: () async => Directory('build/review/online-cache'),
        );
        final result = await store.forTrack(
          const TrackIdentity(
            title: 'Beat It',
            artist: 'Michael Jackson',
            album: 'Thriller',
            duration: null,
            sourcePackage: 'review',
          ),
        );
        expect(result.artistImage, isNotNull);
        expect(result.objects, contains('guitar'));
        await Directory('build/review').create(recursive: true);
        await File(
          'build/review/online-michael-jackson.png',
        ).writeAsBytes(result.artistImage!);
        final codec = await ui.instantiateImageCodec(
          result.artistImage!,
          targetWidth: 320,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        final raw = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        expect(raw[3], 0);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
        canvas.drawImageRect(
          frame.image,
          Rect.fromLTWH(
            0,
            0,
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          ),
          const Rect.fromLTWH(210, 48, 160, 284),
          Paint()
            ..colorFilter = ColorFilter.mode(
              Colors.white.withValues(alpha: .26),
              BlendMode.srcIn,
            ),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(384, 420);
        picture.dispose();
        frame.image.dispose();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(
          'build/review/online-artist-background.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        store.dispose();
      }, RealNetwork());
    },
  );
}
