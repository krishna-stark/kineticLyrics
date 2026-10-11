import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/now_playing/now_playing_track.dart';

void main() {
  test('parses a native track payload', () {
    final track = NowPlayingTrack.fromMap({
      'sourcePackage': 'com.example.player',
      'sourceName': 'Example Player',
      'title': 'A Song',
      'artist': 'An Artist',
      'album': 'An Album',
      'durationMs': 180000,
      'positionMs': 42000,
      'playbackSpeed': 1.0,
      'state': 'playing',
    });

    expect(track.title, 'A Song');
    expect(track.duration, const Duration(minutes: 3));
    expect(track.position, const Duration(seconds: 42));
    expect(track.state, PlaybackStatus.playing);
  });

  test('extrapolates and clamps live playback position', () {
    final receivedAt = DateTime(2026);
    final track = NowPlayingTrack(
      sourcePackage: 'com.example.player',
      sourceName: 'Example Player',
      title: 'A Song',
      artist: 'An Artist',
      album: null,
      duration: const Duration(seconds: 12),
      position: const Duration(seconds: 10),
      playbackSpeed: 1,
      state: PlaybackStatus.playing,
      receivedAt: receivedAt,
    );

    expect(
      track.positionAt(receivedAt.add(const Duration(seconds: 1))),
      const Duration(seconds: 11),
    );
    expect(
      track.positionAt(receivedAt.add(const Duration(seconds: 8))),
      const Duration(seconds: 12),
    );
  });
}
