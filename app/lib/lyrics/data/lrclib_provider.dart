import '../domain/lyric_timeline.dart';
import '../domain/track_identity.dart';
import 'json_http_client.dart';
import 'lrc_parser.dart';
import 'lyrics_provider.dart';

class LrcLibProvider implements LyricsProvider {
  LrcLibProvider({required JsonHttpClient client, LrcParser? parser})
    : this._(client, parser ?? LrcParser());

  LrcLibProvider._(this._client, this._parser);

  final JsonHttpClient _client;
  final LrcParser _parser;

  @override
  String get id => 'lrclib';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async {
    final parameters = <String, String>{
      'track_name': track.title,
      if (track.artist.isNotEmpty) 'artist_name': track.artist,
      if (track.album?.isNotEmpty == true) 'album_name': track.album!,
    };
    final uri = Uri.https('lrclib.net', '/api/search', parameters);
    final response = await _client.get(uri);
    if (response is! List) return null;

    final candidates = response
        .whereType<Map>()
        .map((value) => Map<String, Object?>.from(value))
        .where((value) => value['instrumental'] != true)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _score(b, track).compareTo(_score(a, track)));
    final winner = candidates.first;
    if (_score(winner, track) < 35) return null;

    final synced = winner['syncedLyrics'] as String?;
    if (synced?.trim().isNotEmpty == true) {
      final lines = _parser.parse(synced!, trackDuration: track.duration);
      if (lines.isNotEmpty) {
        return LyricTimeline(
          provider: id,
          quality:
              lines
                  .where((l) => l.text.isNotEmpty)
                  .every(
                    (l) =>
                        l.words.isNotEmpty &&
                        l.words.every(
                          (w) => w.provenance == TimingProvenance.provider,
                        ),
                  )
              ? LyricsTimingQuality.wordSynced
              : LyricsTimingQuality.lineSynced,
          lines: lines,
        );
      }
    }

    final plain = winner['plainLyrics'] as String?;
    if (plain?.trim().isNotEmpty == true) {
      final lines = _parser.estimatePlain(
        plain!,
        trackDuration: track.duration,
      );
      if (lines.isNotEmpty) {
        return LyricTimeline(
          provider: id,
          quality: LyricsTimingQuality.unsynced,
          lines: lines,
        );
      }
    }
    return null;
  }

  int _score(Map<String, Object?> candidate, TrackIdentity track) {
    final candidateTitle = TrackIdentity.normalize(
      candidate['trackName'] as String? ?? '',
    );
    final candidateArtist = TrackIdentity.normalize(
      candidate['artistName'] as String? ?? '',
    );
    final wantedTitle = TrackIdentity.normalize(track.title);
    final wantedArtist = TrackIdentity.normalize(track.artist);

    var score = 0;
    if (candidateTitle == wantedTitle) {
      score += 50;
    } else if (candidateTitle.contains(wantedTitle) ||
        wantedTitle.contains(candidateTitle)) {
      score += 28;
    }
    if (candidateArtist == wantedArtist) {
      score += 30;
    } else if (candidateArtist.contains(wantedArtist) ||
        wantedArtist.contains(candidateArtist)) {
      score += 16;
    }

    final candidateDuration = (candidate['duration'] as num?)?.round();
    final wantedDuration = track.duration?.inSeconds;
    if (candidateDuration != null && wantedDuration != null) {
      final difference = (candidateDuration - wantedDuration).abs();
      score += switch (difference) {
        <= 2 => 30,
        <= 5 => 18,
        <= 10 => 8,
        _ => -20,
      };
    }
    if ((candidate['syncedLyrics'] as String?)?.isNotEmpty == true) score += 8;
    return score;
  }
}
