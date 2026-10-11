import '../domain/lyric_timeline.dart';
import '../domain/track_identity.dart';
import 'lyrics_provider.dart';

class LyricsRepository {
  LyricsRepository({required List<LyricsProvider> providers})
    : _providers = List.unmodifiable(providers);

  final List<LyricsProvider> _providers;
  final Map<String, LyricTimeline?> _cache = {};

  Future<LyricTimeline?> find(TrackIdentity track) async {
    if (_cache.containsKey(track.cacheKey)) return _cache[track.cacheKey];
    var failed = false;
    for (final provider in _providers) {
      try {
        final result = await provider.find(track);
        if (result != null) {
          _cache[track.cacheKey] = result;
          return result;
        }
      } catch (_) {
        // Continue through local and remote sources before reporting a failure.
        failed = true;
      }
    }
    if (failed) throw const LyricsLookupException();
    return null;
  }

  void invalidate(TrackIdentity track) => _cache.remove(track.cacheKey);
}

class LyricsLookupException implements Exception {
  const LyricsLookupException();
}
