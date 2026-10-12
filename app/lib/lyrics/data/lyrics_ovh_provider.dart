import 'dart:io';
import '../domain/lyric_timeline.dart';
import '../domain/track_identity.dart';
import 'json_http_client.dart';
import 'lyrics_provider.dart';

/// Independent plain-text fallback. Never invent timestamps for its response.
class LyricsOvhProvider implements LyricsProvider {
  LyricsOvhProvider({required JsonHttpClient client}) : this._(client);
  LyricsOvhProvider._(this._client);
  final JsonHttpClient _client;
  @override
  String get id => 'lyrics.ovh';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async {
    if (track.artist.trim().isEmpty || track.title.trim().isEmpty) return null;
    final title = track.title
        .replaceAll(
          RegExp(
            r'\s*\(From\s+["\u201c].*?["\u201d]\)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    Object? response;
    try {
      response = await _client.get(
        Uri(
          scheme: 'https',
          host: 'api.lyrics.ovh',
          pathSegments: ['v1', track.artist.trim(), title],
        ),
      );
    } on LyricsHttpException catch (error) {
      if (error.statusCode == HttpStatus.notFound) return null;
      rethrow;
    }
    if (response is! Map || response['lyrics'] is! String) return null;
    final text = (response['lyrics'] as String).trim();
    if (text.isEmpty || text.length > 100000 || text.contains('<html')) {
      return null;
    }
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('Paroles de la chanson '))
        .map(
          (s) => LyricLine(
            text: s,
            start: Duration.zero,
            end: Duration.zero,
            confidence: 0,
          ),
        )
        .toList();
    return lines.isEmpty
        ? null
        : LyricTimeline(
            provider: id,
            quality: LyricsTimingQuality.unsynced,
            lines: lines,
          );
  }
}
