import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/data/json_http_client.dart';
import 'package:kinetic_lyrics/lyrics/data/lrclib_provider.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_provider.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';

void main() {
  const track = TrackIdentity(
    title: 'A Song (Remastered 2026)',
    artist: 'An Artist feat. Someone',
    album: 'An Album',
    duration: Duration(seconds: 219),
    sourcePackage: 'com.example.player',
  );

  test(
    'LRCLIB adapter ranks the matching duration above another version',
    () async {
      final provider = LrcLibProvider(
        client: _FakeHttpClient([
          {
            'trackName': 'A Song',
            'artistName': 'An Artist',
            'duration': 300,
            'instrumental': false,
            'syncedLyrics': '[00:01.00]Wrong version',
          },
          {
            'trackName': 'A Song',
            'artistName': 'An Artist',
            'duration': 219,
            'instrumental': false,
            'syncedLyrics': '[00:01.00]Correct version',
          },
        ]),
      );

      final result = await provider.find(track);
      expect(result?.lines.single.text, 'Correct version');
      expect(result?.quality, LyricsTimingQuality.lineSynced);
    },
  );

  test(
    'repository isolates a provider failure and continues the chain',
    () async {
      final expected = LyricTimeline(
        provider: 'fallback',
        quality: LyricsTimingQuality.lineSynced,
        lines: const [],
      );
      final repository = LyricsRepository(
        providers: [_ThrowingProvider(), _StaticProvider(expected)],
      );

      expect(await repository.find(track), same(expected));
    },
  );

  test('normalization preserves multilingual letters', () {
    expect(TrackIdentity.normalize('रात की रोशनी'), 'रात की रोशनी');
    expect(TrackIdentity.normalize('夜に駆ける'), '夜に駆ける');
  });
}

class _FakeHttpClient implements JsonHttpClient {
  _FakeHttpClient(this.value);
  final Object? value;

  @override
  Future<Object?> get(Uri uri) async => value;
}

class _ThrowingProvider implements LyricsProvider {
  @override
  String get id => 'broken';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) =>
      throw StateError('provider unavailable');
}

class _StaticProvider implements LyricsProvider {
  _StaticProvider(this.value);
  final LyricTimeline value;

  @override
  String get id => 'fallback';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async => value;
}
