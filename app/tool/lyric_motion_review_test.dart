import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_performance.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'capture entrances and cross-phrase exits with the production renderer',
    () async {
      for (final font in [
        'BebasNeue',
        'CormorantGaramond',
        'NotoSansTelugu',
        'NotoSerifTelugu',
      ]) {
        await (FontLoader(
          font,
        )..addFont(rootBundle.load('assets/fonts/$font.ttf'))).load();
      }
      await (FontLoader(
        'LyricDisplay',
      )..addFont(rootBundle.load('assets/fonts/LyricDisplay-Bold.ttf'))).load();
      for (final transition in SemanticTransition.values) {
        final native = transition == SemanticTransition.lift;
        LyricScene scene(String text, int start, int index) {
          final tokens = text.split(' ');
          return LyricScene(
            LyricLine(
              text: text,
              start: Duration(milliseconds: start),
              end: Duration(milliseconds: start + 2000),
              words: [
                for (var i = 0; i < tokens.length; i++)
                  LyricWord(
                    text: tokens[i],
                    start: Duration(milliseconds: start + i * 450),
                    end: Duration(
                      milliseconds: i == tokens.length - 1
                          ? start + 2000
                          : start + (i + 1) * 450,
                    ),
                    confidence: .94,
                    provenance: TimingProvenance.provider,
                  ),
              ],
            ),
            index,
            native ? LyricMood.romantic : LyricMood.urgent,
            0,
          );
        }

        final first = scene(
          native ? 'ప్రేమ ప్రతి క్షణం' : 'Find our rhythm',
          1000,
          0,
        );
        final next = scene(
          native ? 'నీతో నా ప్రయాణం' : 'Carry it forward',
          3000,
          1,
        );
        final base = LyricComposition.prepare(
          first,
          const Size(280, 300),
          TextDirection.ltr,
        );
        final second = LyricComposition.prepare(
          next,
          const Size(280, 300),
          TextDirection.ltr,
        );
        final composition = LyricComposition([
          for (final s in base.shots)
            LyricShot(s.start, s.end, s.words, s.family, transition),
        ]);
        final following = LyricComposition([
          for (final s in second.shots)
            LyricShot(s.start, s.end, s.words, s.family, transition),
        ]);
        final folder = Directory('build/review/motion-${transition.name}');
        await folder.create(recursive: true);
        for (var frame = 0; frame < 90; frame++) {
          final position = Duration(milliseconds: 600 + frame * 40);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawColor(Colors.black, BlendMode.src);
          canvas.save();
          canvas.clipRect(const Rect.fromLTWH(0, 64, 384, 490));
          LyricPerformance.paint(
            canvas,
            const Size(384, 832),
            first,
            composition,
            position,
            handoff: true,
          );
          LyricPerformance.paint(
            canvas,
            const Size(384, 832),
            next,
            following,
            position,
          );
          canvas.restore();
          final label = TextPainter(
            text: TextSpan(
              text:
                  '${transition.name.toUpperCase()} · ${position.inMilliseconds} ms',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, const Offset(20, 20));
          label.dispose();
          final pic = recorder.endRecording();
          final image = await pic.toImage(384, 832);
          pic.dispose();
          await File(
            '${folder.path}/${frame.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          image.dispose();
        }
        base.dispose();
        second.dispose();
      }
    },
  );
}
