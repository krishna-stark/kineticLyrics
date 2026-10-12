import 'dart:async';

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
    final complete = Completer<LyricTimeline?>();
    var remaining = _providers.length;
    var failed = false;
    LyricTimeline? fallback;
    var fallbackPriority = _providers.length;
    if (remaining == 0) return null;
    for (var index = 0; index < _providers.length; index++) {
      final priority = index;
      unawaited(
        Future<LyricTimeline?>.sync(() => _providers[priority].find(track))
            .timeout(const Duration(seconds: 12))
            .then(
              (result) {
                if (complete.isCompleted || result == null) return;
                if (result.quality == LyricsTimingQuality.lineSynced ||
                    result.quality == LyricsTimingQuality.wordSynced) {
                  complete.complete(result);
                } else if (fallback == null || priority < fallbackPriority) {
                  fallback = result;
                  fallbackPriority = priority;
                }
              },
              onError: (Object _) {
                failed = true;
              },
            )
            .whenComplete(() {
              remaining--;
              if (remaining == 0 && !complete.isCompleted) {
                if (fallback != null || !failed) {
                  complete.complete(fallback);
                } else {
                  complete.completeError(const LyricsLookupException());
                }
              }
            }),
      );
    }
    final result = await complete.future;
    // Do not pin misses: a later retry or connection recovery should re-query.
    if (result != null) _cache[track.cacheKey] = result;
    return result;
  }

  void invalidate(TrackIdentity track) => _cache.remove(track.cacheKey);
}

class LyricsLookupException implements Exception {
  const LyricsLookupException();
}
