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

  test('published synchronized lyrics supersede a saved AI draft', () async {
    final draft = LyricTimeline(
      provider: 'on-device',
      quality: LyricsTimingQuality.estimated,
      lines: const [],
    );
    final published = LyricTimeline(
      provider: 'lrclib',
      quality: LyricsTimingQuality.lineSynced,
      lines: const [],
    );
    final repository = LyricsRepository(
      providers: [_StaticProvider(draft), _StaticProvider(published)],
    );
    expect(await repository.find(track), same(published));
  });
  test(
    'same-title wrong artist and mismatched recording are rejected',
    () async {
      for (final candidate in [
        {'trackName': 'A Song', 'artistName': 'Someone Else', 'duration': 219},
        {'trackName': '', 'artistName': 'An Artist', 'duration': 219},
        {'trackName': 'A Song', 'artistName': 'An Artist', 'duration': 300},
      ]) {
        final provider = LrcLibProvider(
          client: _FakeHttpClient([
            {...candidate, 'syncedLyrics': '[00:01.00]Wrong lyrics'},
          ]),
        );
        expect(await provider.find(track), isNull);
      }
    },
  );
  test(
    'film decoration falls back to clean title without dropping identity checks',
    () async {
      final client = _SearchFallback();
      final provider = LrcLibProvider(client: client);
      final result = await provider.find(
        const TrackIdentity(
          title: 'Nee Chuttu (From "Skanda")',
          artist: 'Singer',
          album: 'Film',
          duration: Duration(seconds: 180),
          sourcePackage: 'player',
        ),
      );
      expect(result?.lines.first.text, 'Matched lyric');
      expect(client.queries, hasLength(2));
      expect(client.queries.last.queryParameters['track_name'], 'Nee Chuttu');
      expect(
        client.queries.last.queryParameters,
        isNot(contains('album_name')),
      );
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

class _SearchFallback implements JsonHttpClient {
  final queries = <Uri>[];
  @override
  Future<Object?> get(Uri uri) async {
    queries.add(uri);
    if (uri.queryParameters.containsKey('album_name')) return [];
    return [
      {
        'trackName': 'Nee Chuttu',
        'artistName': 'Singer',
        'duration': 180,
        'syncedLyrics': '[00:01.00]Matched lyric',
      },
    ];
  }
}
