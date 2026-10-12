import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/data/json_http_client.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_ovh_provider.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_repository.dart';
import 'package:kinetic_lyrics/lyrics/data/lyrics_provider.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';

const track = TrackIdentity(
  title: 'ప్రేమ / Song',
  artist: 'Artist & Singer',
  album: null,
  duration: Duration(seconds: 180),
  sourcePackage: 'player',
);
void main() {
  test('fallback preserves native text and safely encodes metadata', () async {
    final client = Client();
    final result = await LyricsOvhProvider(client: client).find(track);
    expect(client.uri!.pathSegments.last, track.title);
    expect(client.uri!.pathSegments[1], track.artist);
    expect(result!.quality, LyricsTimingQuality.unsynced);
    expect(result.lines.first.text, 'ప్రేమ నీతో');
    expect(result.lines.first.words, isEmpty);
    expect(result.lines.first.start, Duration.zero);
  });
  test('a stalled source cannot delay another synchronized result', () async {
    final slow = Completer<LyricTimeline?>();
    final synced = LyricTimeline(
      provider: 'synced',
      quality: LyricsTimingQuality.lineSynced,
      lines: const [],
    );
    final repository = LyricsRepository(
      providers: [Provider(slow.future), Provider(Future.value(synced))],
    );
    expect(await repository.find(track), same(synced));
    slow.complete(null);
  });
}

class Client implements JsonHttpClient {
  Uri? uri;
  @override
  Future<Object?> get(Uri value) async {
    uri = value;
    return {'lyrics': 'ప్రేమ నీతో\nNext line'};
  }
}

class Provider implements LyricsProvider {
  Provider(this.result);
  final Future<LyricTimeline?> result;
  @override
  String get id => 'test';
  @override
  Future<LyricTimeline?> find(TrackIdentity track) => result;
}
