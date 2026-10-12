import 'dart:convert';
import 'dart:io';

abstract interface class JsonHttpClient {
  Future<Object?> get(Uri uri);
}

class LyricsHttpException extends HttpException {
  LyricsHttpException(this.statusCode, Uri uri)
    : super('Lyrics service returned $statusCode', uri: uri);
  final int statusCode;
}

class DartJsonHttpClient implements JsonHttpClient {
  DartJsonHttpClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<Object?> get(Uri uri) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'KineticLyrics/1.0');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LyricsHttpException(response.statusCode, uri);
    }
    return jsonDecode(body);
  }
}
