import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../lyrics/domain/track_identity.dart';
import 'on_device_semantic_analyzer.dart';

class OnlineSongContext {
  const OnlineSongContext({
    this.objects = const [],
    this.artistImage,
    this.source,
  });
  final List<String> objects;
  final Uint8List? artistImage;
  final String? source;
}

/// Public song/artist discovery, independent of lyrics loading and rendering.
/// Bounded requests, reusable jobs, disk cache, and no downloaded executable SVG.
class OnlineSongContextStore {
  OnlineSongContextStore({
    this.get,
    this.download,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheDirectory = cacheDirectory ?? getApplicationSupportDirectory;
  final Future<Object?> Function(Uri)? get;
  final Future<Uint8List> Function(Uri)? download;
  final Future<Directory> Function() _cacheDirectory;
  final _client = HttpClient()
    ..userAgent = 'KineticLyrics/1.0 (song visual context)';
  final _jobs = <String, Future<OnlineSongContext>>{};
  bool _disposed = false;

  Future<OnlineSongContext> forTrack(TrackIdentity track) {
    if (_disposed || track.artist.trim().isEmpty) {
      return Future.value(const OnlineSongContext());
    }
    // Bound in-memory retention across long listening sessions.
    if (_jobs.length >= 12 && !_jobs.containsKey(track.cacheKey)) {
      _jobs.remove(_jobs.keys.first);
    }
    return _jobs.putIfAbsent(track.cacheKey, () => _load(track));
  }

  Future<OnlineSongContext> _load(TrackIdentity track) async {
    File? metadata;
    File? image;
    try {
      final root = await _cacheDirectory();
      final directory = Directory('${root.path}/song-context-v1');
      await directory.create(recursive: true);
      var hash = 2166136261;
      for (final unit in track.cacheKey.codeUnits) {
        hash = ((hash ^ unit) * 16777619) & 0xffffffff;
      }
      metadata = File('${directory.path}/$hash.json');
      image = File('${directory.path}/$hash.png');
      if (await metadata.exists()) {
        final saved =
            jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
        if (saved['key'] == track.cacheKey &&
            (saved['expires'] as int) > DateTime.now().millisecondsSinceEpoch) {
          return OnlineSongContext(
            objects: (saved['objects'] as List).cast<String>(),
            source: saved['source'] as String?,
            artistImage: saved['image'] == true && await image.exists()
                ? await image.readAsBytes()
                : null,
          );
        }
      }
    } catch (_) {
      /* Optional cache failure must not prevent discovery. */
    }
    final results = await Future.wait([
      _songObjects(track),
      _artistSilhouette(track.artist),
    ]);
    final song = results[0];
    final artist = results[1];
    final result = OnlineSongContext(
      objects: song.objects,
      artistImage: artist.artistImage,
      source: artist.source ?? song.source,
    );
    if (!_disposed && metadata != null && image != null) {
      try {
        if (result.artistImage != null) {
          await image.writeAsBytes(result.artistImage!, flush: true);
        }
        await metadata.writeAsString(
          jsonEncode({
            'key': track.cacheKey,
            'expires': DateTime.now()
                .add(Duration(hours: result.source == null ? 6 : 168))
                .millisecondsSinceEpoch,
            'objects': result.objects,
            'source': result.source,
            'image': result.artistImage != null,
          }),
        );
      } catch (_) {
        /* Rendering never depends on disk writes. */
      }
    }
    return result;
  }

  Future<OnlineSongContext> _songObjects(TrackIdentity track) async {
    try {
      final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch':
            '${TrackIdentity.normalize(track.title)} ${TrackIdentity.normalize(track.artist)}',
        'gsrlimit': '3',
        'prop': 'extracts|info',
        'exintro': '1',
        'explaintext': '1',
        'exchars': '1200',
        'inprop': 'url',
        'format': 'json',
        'formatversion': '2',
      });
      final response = await _json(uri);
      for (final page in _pages(response)) {
        final title = TrackIdentity.normalize(page['title'] as String? ?? '');
        final text = page['extract'] as String? ?? '';
        final normalized = TrackIdentity.normalize(text);
        // Reject covers, games, biographies and homonyms returned by search.
        final wanted = TrackIdentity.normalize(track.title);
        final artist = TrackIdentity.normalize(track.artist);
        if (!(title == wanted || title == '$wanted song') ||
            !normalized.contains(artist) ||
            !RegExp(r'\b(song|single)\b').hasMatch(normalized)) {
          continue;
        }
        // Only visual themes/instruments, not incidental dates/chart trivia.
        final themeSentences = text
            .split(RegExp(r'[.!?]'))
            .where(
              (sentence) => RegExp(
                r'\b(lyrics|lyrical|theme|video|guitar|piano|drum)\b',
                caseSensitive: false,
              ).hasMatch(sentence),
            )
            .join('.');
        final objects = OnDeviceE5SemanticAnalyzer.lexicalObjectsFor(
          themeSentences,
          limit: 2,
        ).map((kind) => kind.name).toList();
        if (RegExp(
          r'\bguitar\b',
          caseSensitive: false,
        ).hasMatch(themeSentences)) {
          objects.insert(0, 'guitar');
        }
        return OnlineSongContext(
          objects: objects.take(2).toList(),
          source: page['fullurl'] as String?,
        );
      }
    } catch (_) {
      /* Missing article or network: retain the local director. */
    }
    return const OnlineSongContext();
  }

  Future<OnlineSongContext> _artistSilhouette(String artist) async {
    try {
      final response = await _json(
        Uri.https('commons.wikimedia.org', '/w/api.php', {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': '${TrackIdentity.normalize(artist)} silhouette',
          'gsrnamespace': '6',
          'gsrlimit': '5',
          'prop': 'imageinfo',
          'iiprop': 'url|extmetadata',
          'iiurlwidth': '320',
          'format': 'json',
          'formatversion': '2',
        }),
      );
      final candidate = selectSilhouette(response, artist);
      if (candidate == null) return const OnlineSongContext();
      final bytes =
          await (download?.call(candidate.image) ?? _bytes(candidate.image));
      if (bytes.length > 512 * 1024) return const OnlineSongContext();
      return OnlineSongContext(
        artistImage: bytes,
        source: candidate.source.toString(),
      );
    } catch (_) {
      return const OnlineSongContext();
    }
  }

  static SilhouetteReference? selectSilhouette(
    Object? response,
    String artist,
  ) {
    final wanted = TrackIdentity.normalize(artist);
    if (wanted.length < 3) return null;
    for (final page in _pages(response)) {
      final title = TrackIdentity.normalize(
        (page['title'] as String? ?? '').replaceFirst('File:', ''),
      );
      if (!title.contains(wanted) ||
          !(page['title'] as String? ?? '').toLowerCase().endsWith('.svg')) {
        continue;
      }
      final infos = page['imageinfo'] as List? ?? const [];
      if (infos.isEmpty) continue;
      final info = infos.first as Map;
      final meta = info['extmetadata'] as Map? ?? const {};
      String value(String key) =>
          (meta[key] as Map?)?['value']?.toString() ?? '';
      if (!value('Categories').toLowerCase().contains('silhouette')) continue;
      if (![
            'public domain',
            'cc0',
          ].contains(value('LicenseShortName').toLowerCase()) ||
          value('AttributionRequired') != 'false') {
        continue;
      }
      final image = Uri.tryParse(info['thumburl'] as String? ?? '');
      final source = Uri.tryParse(info['descriptionurl'] as String? ?? '');
      if (image == null ||
          source == null ||
          image.scheme != 'https' ||
          ![
            'thumb.wikimedia.org',
            'upload.wikimedia.org',
          ].contains(image.host) ||
          !image.path.endsWith('.png') ||
          source.host != 'commons.wikimedia.org') {
        continue;
      }
      return SilhouetteReference(image, source);
    }
    return null;
  }

  static List<Map<String, dynamic>> _pages(Object? response) {
    if (response is! Map) return const [];
    final query = response['query'];
    if (query is! Map || query['pages'] is! List) return const [];
    final pages = (query['pages'] as List)
        .whereType<Map>()
        .map((p) => p.cast<String, dynamic>())
        .toList();
    pages.sort(
      (a, b) =>
          ((a['index'] as num?) ?? 99).compareTo((b['index'] as num?) ?? 99),
    );
    return pages;
  }

  Future<Object?> _json(Uri uri) async {
    if (get != null) return get!(uri).timeout(const Duration(seconds: 6));
    final bytes = await _bytes(uri);
    return Isolate.run(() => jsonDecode(utf8.decode(bytes)));
  }

  Future<Uint8List> _bytes(Uri uri) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    final deadline = Timer(
      const Duration(seconds: 6),
      () => request.abort(const HttpException('Context timed out')),
    );
    try {
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) {
        request.abort();
        throw const HttpException('Context unavailable');
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        buffer.add(chunk);
        if (buffer.length > 512 * 1024) {
          request.abort();
          throw const HttpException('Context exceeds budget');
        }
      }
      return buffer.takeBytes();
    } finally {
      deadline.cancel();
    }
  }

  void dispose() {
    _disposed = true;
    _client.close(force: true);
    _jobs.clear();
  }
}

class SilhouetteReference {
  const SilhouetteReference(this.image, this.source);
  final Uri image;
  final Uri source;
}
