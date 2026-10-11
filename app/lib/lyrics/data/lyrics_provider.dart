import '../domain/lyric_timeline.dart';
import '../domain/track_identity.dart';

abstract interface class LyricsProvider {
  String get id;

  Future<LyricTimeline?> find(TrackIdentity track);
}
