import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/app/performance_library.dart';
import 'package:kinetic_lyrics/lyrics/data/lrc_parser.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/lyric_composition.dart';
import 'package:kinetic_lyrics/visuals/lyric_performance.dart';
import 'package:kinetic_lyrics/visuals/performance_settings.dart';
import 'package:kinetic_lyrics/visuals/song_score.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
  });
  LyricTimeline timeline(List<String> texts) => LyricTimeline(
    provider: 'fixture',
    quality: LyricsTimingQuality.lineSynced,
    lines: [
      for (var i = 0; i < texts.length; i++)
        LyricLine(
          text: texts[i],
          start: Duration(seconds: i * 5),
          end: Duration(seconds: (i + 1) * 5),
        ),
    ],
  );

  test(
    'multi-line refrain returns with the same motif and font; fillers are not a chorus',
    () {
      final score = SongScore.prepare(
        timeline([
          'A quiet beginning',
          'Find our rhythm',
          'Carry it home',
          'Another verse arrives',
          'Find our rhythm',
          'Carry it home',
          'oh',
          'oh',
        ]),
        identity: 'Song/Artist',
      );
      expect(score.scenes[1].section, SongSection.refrain);
      expect(score.scenes[2].section, SongSection.refrain);
      expect(score.scenes[4].motif, score.scenes[1].motif);
      expect(
        LyricComposition.fontFor(score.scenes[1]),
        LyricComposition.fontFor(score.scenes[4]),
      );
      expect(score.scenes[6].refrain, isFalse);
      expect(score.scenes[7].refrain, isFalse);
      expect(
        score.scenes.map(LyricComposition.fontFor).toSet().length,
        greaterThan(1),
      );
    },
  );
  test(
    'literal native object changes promptly and unsupported context expires',
    () {
      final score = SongScore.prepare(
        timeline([
          'வானத்தில் நிலா',
          'nothing specific',
          'nothing known',
          'గులాబీ ప్రేమ',
        ]),
        identity: 'native',
        songObjects: ['musicNote'],
      );
      expect(score.objects[0], 'moon');
      expect(score.objects[1], 'moon');
      expect(score.objects[2], isNull);
      expect(score.objects[3], 'rose');
    },
  );
  test(
    'enhanced LRC preserves real word timing, vocal role and repeated time tags',
    () {
      final lines = LrcParser().parse(
        '[00:01.00][00:11.00][voice:response]<00:01.00>కాదల్ <00:02.00>love<00:03.00>\n[00:05.00]next\n[00:15.00]last',
        trackDuration: const Duration(seconds: 20),
      );
      expect(lines.first.vocalRole, VocalRole.response);
      expect(lines.first.text, 'కాదల్ love');
      expect(lines.first.words.last.end, const Duration(seconds: 3));
      expect(lines[2].words.first.start, const Duration(seconds: 11));
      expect(
        lines.first.words.every(
          (w) => w.provenance == TimingProvenance.provider,
        ),
        isTrue,
      );
      final enriched = LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.wordSynced,
        lines: lines,
      ).enrich();
      expect(enriched.lines.first.vocalRole, VocalRole.response);
      final bad = LrcParser().parse(
        '[00:01.00]<00:02.00>a<00:01.00>b',
        trackDuration: const Duration(seconds: 4),
      );
      expect(bad.first.words.first.provenance, TimingProvenance.estimated);
    },
  );
  test(
    'automatic choreography does not invent singers; user layout does alternate',
    () {
      final source = timeline(['A phrase', 'A response']);
      final auto = SongScore.prepare(source, identity: 'song');
      expect(auto.scenes.every((s) => s.vocalRole == VocalRole.lead), isTrue);
      final duet = SongScore.prepare(
        source,
        identity: 'song',
        vocalLayout: VocalLayout.callAndResponse,
      );
      expect(duet.scenes[1].vocalRole, VocalRole.response);
      expect(
        LyricComposition.fontFor(duet.scenes.first),
        isNot(LyricComposition.fontFor(duet.scenes.last)),
      );
    },
  );
  test(
    'estimated words remain readable; precise words follow onsets and held notes breathe',
    () {
      final line = timeline(['Hold our rhythm']).enrich().lines.first;
      final scene = LyricScene(line, 0, LyricMood.quiet, 0);
      final composition = LyricComposition.prepare(
        scene,
        const Size(280, 320),
        TextDirection.ltr,
      );
      final shot = composition.shots.first;
      final upcoming = shot.words.last;
      final pose = VocalWordPose.sample(
        item: upcoming,
        shot: shot,
        scene: scene,
        position: shot.start + const Duration(milliseconds: 300),
        intensity: .8,
      );
      expect(pose.opacity, greaterThan(.95));
      final entering = VocalWordPose.sample(
        item: shot.words.first,
        shot: shot,
        scene: scene,
        position: shot.start + const Duration(milliseconds: 80),
        intensity: .8,
      );
      expect(entering.opacity, greaterThan(.5));
      expect(entering.dy.abs() + entering.dx.abs(), greaterThan(1));
      expect(shot.motion.precise, isFalse);

      expect(
        VocalWordPose.sample(
          item: upcoming,
          shot: shot,
          scene: scene,
          position: shot.start,
          reduced: true,
          intensity: 1,
        ).opacity,
        1,
      );
      composition.dispose();
    },
  );
  test(
    'motion anticipates only verified words and keeps the final word readable',
    () {
      const word = LyricWord(
        text: 'Stay',
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        confidence: .94,
        provenance: TimingProvenance.provider,
      );
      const line = LyricLine(
        text: 'Stay',
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        words: [word],
      );
      final scene = LyricScene(line, 0, LyricMood.romantic, 0);
      final base = LyricComposition.prepare(
        scene,
        const Size(270, 280),
        TextDirection.ltr,
      );
      final trajectories = <String>{};
      for (final transition in SemanticTransition.values) {
        final shot = LyricShot(
          line.start,
          line.end,
          base.shots.first.words,
          CompositionFamily.spotlight,
          transition,
        );
        final composition = LyricComposition([shot]);
        expect(
          composition.visibleAt(const Duration(milliseconds: 940)),
          contains(shot),
        );
        VocalWordPose sample(int ms) => VocalWordPose.sample(
          item: shot.words.first,
          shot: shot,
          scene: scene,
          position: Duration(milliseconds: ms),
          intensity: 1,
        );
        final arrival = sample(940);
        expect(arrival.opacity, greaterThan(0));
        trajectories.add(
          '${arrival.dx}/${arrival.dy}/${arrival.scale}/${arrival.reveal}',
        );
        expect(sample(1000).opacity, 1);
        expect(sample(2999).opacity, 1);
        expect(sample(3000).opacity, 1);
        expect(sample(3100).opacity, inExclusiveRange(0, 1));
        expect(
          composition.visibleAt(const Duration(milliseconds: 3300)),
          isEmpty,
        );
        final held = sample(1400);
        sample(3100); // seek backward after an outgoing frame
        expect(sample(1400).scale, held.scale);
        expect(sample(1400).opacity, held.opacity);
      }
      expect(trajectories.length, SemanticTransition.values.length);
      final estimated = LyricComposition.prepare(
        LyricScene(
          timeline(['Stay']).enrich().lines.first,
          0,
          LyricMood.romantic,
          0,
        ),
        const Size(270, 280),
        TextDirection.ltr,
      );
      expect(estimated.shots.first.motion.anticipationMs, 0);
      expect(estimated.visibleAt(const Duration(milliseconds: -50)), isEmpty);
      expect(
        base.visibleAt(const Duration(milliseconds: 940), reduced: true),
        isEmpty,
      );
      estimated.dispose();
      base.dispose();
    },
  );
  test(
    'handoffs bound outgoing groups and reduced motion uses only the active shot',
    () {
      final scene = LyricScene(
        timeline(['Words']).enrich().lines.first,
        0,
        LyricMood.urgent,
        0,
      );
      final base = LyricComposition.prepare(
        scene,
        const Size(270, 280),
        TextDirection.ltr,
      );
      final shots = [
        for (var i = 0; i < 8; i++)
          LyricShot(
            Duration(milliseconds: i * 20),
            Duration(milliseconds: (i + 1) * 20),
            base.shots.first.words,
            CompositionFamily.assembly,
            SemanticTransition.slide,
          ),
      ];
      final composition = LyricComposition(shots);
      final visible = composition
          .visibleAt(const Duration(milliseconds: 125))
          .toList();
      expect(
        visible.where((s) => s.end <= const Duration(milliseconds: 125)).length,
        2,
      );
      expect(
        composition
            .visibleAt(const Duration(milliseconds: 125), reduced: true)
            .length,
        1,
      );
      base.dispose();
    },
  );
  test(
    'haptics are sparse, timestamp-deduplicated and reset safely on seeks',
    () {
      final gate = HapticAccentGate();
      bool pulse(int event, int play, double hit) => gate.accept(
        timestamp: Duration(milliseconds: event),
        playback: Duration(milliseconds: play),
        attack: hit,
        energy: .8,
      );
      expect(pulse(1, 1000, .9), isTrue);
      expect(pulse(1, 1800, .9), isFalse);
      expect(pulse(2, 1400, .9), isFalse);
      expect(pulse(3, 1800, .3), isFalse);
      expect(pulse(4, 1800, .9), isTrue);
      expect(pulse(5, 100, .9), isTrue);
    },
  );
  test(
    'settings and moments survive reload, duplicate saves, deletion and concurrent writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kinetic-performance-',
      );
      try {
        final library = PerformanceLibrary(directory: () async => directory);
        final moment = LyricMoment(
          identity: 'song/artist',
          title: 'Song',
          artist: 'Artist',
          line: timeline(['Hold the line']).enrich().lines.first,
          mood: LyricMood.quiet,
          section: SongSection.verse,
          fontSeed: 4,
        );
        await Future.wait([
          library.saveMoment(moment),
          library.saveMoment(moment),
          library.update(
            const PerformanceSettings(
              intensity: PerformanceIntensity.concert,
              haptics: true,
            ),
          ),
        ]);
        final reload = PerformanceLibrary(directory: () async => directory);
        await reload.load();
        expect(reload.moments.length, 1);
        expect(reload.settings.intensity, PerformanceIntensity.concert);
        expect(reload.settings.haptics, isTrue);
        expect(reload.moments.first.line.words.last.text, 'line');
        await reload.remove(reload.moments.first);
        final removed = PerformanceLibrary(directory: () async => directory);
        await removed.load();
        expect(removed.moments, isEmpty);
        removed.dispose();
        reload.dispose();
        library.dispose();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'live choreography keeps transformed native and Latin words on screen through all phases',
    () async {
      for (final text in [
        'ప్రేమ ప్రతి క్షణం నీతో',
        'காதல் நம்மை அழைக்கிறது',
        'रात में प्यार की कहानी',
        'Extraordinarily beautiful rhythm',
      ]) {
        final score = SongScore.prepare(timeline([text]), identity: text);
        final scene = score.scenes.first;
        final composition = LyricComposition.prepare(
          scene,
          const Size(270, 280),
          TextDirection.ltr,
        );
        for (final ms in [40, 160, 600, 1400, 2400, 3900, 4800]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawColor(Colors.black, BlendMode.src);
          LyricPerformance.paint(
            canvas,
            const Size(360, 780),
            scene,
            composition,
            Duration(milliseconds: ms),
            settings: const PerformanceSettings(
              intensity: PerformanceIntensity.concert,
            ),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(360, 780);
          picture.dispose();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          for (var y = 0; y < 780; y++) {
            for (var x = 0; x < 360; x++) {
              if ((x < 24 || x >= 336 || y >= 520) &&
                  bytes[(y * 360 + x) * 4] > 5) {
                fail('Lyric crossed safe edge: $text, $ms ms at $x,$y');
              }
            }
          }
          image.dispose();
        }
        composition.dispose();
      }
    },
  );
}
