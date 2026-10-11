import '../../now_playing/now_playing_track.dart';

class TrackIdentity {
  const TrackIdentity({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.sourcePackage,
  });

  factory TrackIdentity.fromNowPlaying(NowPlayingTrack track) => TrackIdentity(
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: track.duration,
    sourcePackage: track.sourcePackage,
  );

  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final String sourcePackage;

  String get cacheKey =>
      [normalize(title), normalize(artist), duration?.inSeconds ?? 0].join('|');

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*(remaster|live|version|edit)[^)]*\)'), '')
      .replaceAll(RegExp(r'\[[^]]*(remaster|live|version|edit)[^]]*\]'), '')
      .replaceAll(RegExp(r'\s+(feat\.?|ft\.?).*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
      .trim();
}
