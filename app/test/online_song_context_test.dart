import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/semantics/online_song_context.dart';

Map<String, dynamic> silhouette({
  String artist = 'Michael Jackson',
  String license = 'Public domain',
  String host = 'thumb.wikimedia.org',
}) => {
  'query': {
    'pages': [
      {
        'title': 'File:$artist.svg',
        'index': 1,
        'imageinfo': [
          {
            'thumburl': 'https://$host/test.png',
            'descriptionurl':
                'https://commons.wikimedia.org/wiki/File:test.svg',
            'extmetadata': {
              'Categories': {'value': 'SVG silhouettes of people'},
              'LicenseShortName': {'value': license},
              'AttributionRequired': {'value': 'false'},
            },
          },
        ],
      },
    ],
  },
};

void main() {
  TrackIdentity track(String title, String artist) => TrackIdentity(
    title: title,
    artist: artist,
    album: null,
    duration: null,
    sourcePackage: 'test',
  );
  late Directory cache;
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('song-context-test');
  });
  tearDown(() async {
    await cache.delete(recursive: true);
  });
  test(
    'generic discovery shares pending jobs and survives reload through disk cache',
    () async {
      var requests = 0, downloads = 0;
      final gate = Completer<void>();
      final store = OnlineSongContextStore(
        cacheDirectory: () async => cache,
        get: (uri) async {
          requests++;
          await gate.future;
          if (uri.host == 'commons.wikimedia.org') {
            return silhouette(artist: 'Sample Artist');
          }
          expect(uri.queryParameters['gsrsearch'], 'sample song sample artist');
          return {
            'query': {
              'pages': [
                {
                  'title': 'Sample Song',
                  'extract':
                      'Sample Song is a song by Sample Artist. It features a guitar solo.',
                  'fullurl': 'https://en.wikipedia.org/wiki/Sample_Song',
                },
              ],
            },
          };
        },
        download: (uri) async {
          downloads++;
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      final identity = track('Sample Song', 'Sample Artist');
      final first = store.forTrack(identity);
      expect(identical(first, store.forTrack(identity)), isTrue);
      gate.complete();
      final result = await first;
      expect(result.objects, contains('guitar'));
      expect(result.artistImage, isNotNull);
      expect(requests, 2);
      expect(downloads, 1);
      store.dispose();
      final restored = OnlineSongContextStore(
        cacheDirectory: () async => cache,
        get: (_) async => throw StateError('Network must not run'),
      );
      final saved = await restored.forTrack(identity);
      expect(saved.objects, contains('guitar'));
      expect(saved.artistImage, [1, 2, 3]);
      restored.dispose();
    },
  );
  test(
    'wrong artist, unsupported license and unrelated image host are rejected',
    () {
      expect(
        OnlineSongContextStore.selectSilhouette(
          silhouette(),
          'Michael Jackson',
        ),
        isNotNull,
      );
      expect(
        OnlineSongContextStore.selectSilhouette(
          silhouette(),
          'Different Artist',
        ),
        isNull,
      );
      expect(
        OnlineSongContextStore.selectSilhouette(
          silhouette(license: 'CC BY 3.0'),
          'Michael Jackson',
        ),
        isNull,
      );
      expect(
        OnlineSongContextStore.selectSilhouette(
          silhouette(host: 'example.com'),
          'Michael Jackson',
        ),
        isNull,
      );
    },
  );
  test(
    'unrelated song results never supply objects and offline lookup fails quietly',
    () async {
      final store = OnlineSongContextStore(
        cacheDirectory: () async => cache,
        get: (uri) async => {
          'query': {
            'pages': [
              {
                'title': 'Wrong Song',
                'extract': 'A song by Sample Artist about fire and rain.',
              },
            ],
          },
        },
      );
      final value = await store.forTrack(track('Sample Song', 'Sample Artist'));
      expect(value.objects, isEmpty);
      expect(value.artistImage, isNull);
      store.dispose();
      final offline = OnlineSongContextStore(
        cacheDirectory: () async => cache,
        get: (_) async => throw const SocketException('Offline'),
      );
      final missed = await offline.forTrack(
        track('Another Song', 'Another Artist'),
      );
      expect(missed.objects, isEmpty);
      expect(missed.artistImage, isNull);
      offline.dispose();
    },
  );
}
