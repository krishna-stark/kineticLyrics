import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/learning/generated_lyrics_store.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';

void main() {
  test(
    'legacy drafts with broken timing cannot override fresh lyrics',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lyric-draft-test',
      );
      try {
        final store = GeneratedLyricsStore(directory: directory);
        const track = TrackIdentity(
          title: 'Song',
          artist: 'Artist',
          album: null,
          duration: Duration(seconds: 180),
          sourcePackage: 'player',
        );
        const timeline = LyricTimeline(
          provider: 'on-device',
          quality: LyricsTimingQuality.estimated,
          lines: [
            LyricLine(
              text: 'ప్రేమ నీతో',
              start: Duration(seconds: 10),
              end: Duration(seconds: 14),
              confidence: .4,
            ),
          ],
        );
        await store.save(track, timeline);
        expect((await store.find(track))?.lines.first.text, 'ప్రేమ నీతో');
        final file =
            (await Directory(
                  '${directory.path}/learned_lyrics',
                ).list().where((f) => f is File).toList()).single
                as File;
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        json['version'] = 1;
        await file.writeAsString(jsonEncode(json));
        expect(await store.find(track), isNull);
        json['version'] = 2;
        json['track'] = 'different track';
        await file.writeAsString(jsonEncode(json));
        expect(await store.find(track), isNull);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
