import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../lyrics/data/lyrics_provider.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../lyrics/domain/track_identity.dart';

class GeneratedLyricsStore implements LyricsProvider {
  GeneratedLyricsStore({this.directory});
  final Directory? directory;
  @override
  String get id => 'on-device';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async {
    final file = await _fileFor(track);
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (json['version'] != 2 || json['track'] != track.cacheKey) return null;
      final lines = (json['lines'] as List)
          .whereType<Map>()
          .map((raw) => _lineFromJson(Map<String, Object?>.from(raw)))
          .toList();
      if (lines.isEmpty) return null;
      return LyricTimeline(
        provider: id,
        quality: LyricsTimingQuality.estimated,
        lines: lines,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(TrackIdentity track, LyricTimeline timeline) async {
    final file = await _fileFor(track);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.partial');
    await temporary.writeAsString(
      jsonEncode({
        'version': 2,
        'track': track.cacheKey,
        'lines': timeline.lines.map(_lineToJson).toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _fileFor(TrackIdentity track) async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/learned_lyrics/${_hash(track.cacheKey)}.json');
  }

  Map<String, Object> _lineToJson(LyricLine line) => {
    'text': line.text,
    'startMs': line.start.inMilliseconds,
    'endMs': line.end.inMilliseconds,
    'confidence': line.confidence,
    'provenance': line.provenance.name,
    'vocalRole': line.vocalRole.name,
    'words': line.words
        .map(
          (word) => {
            'text': word.text,
            'startMs': word.start.inMilliseconds,
            'endMs': word.end.inMilliseconds,
            'confidence': word.confidence,
            'provenance': word.provenance.name,
          },
        )
        .toList(),
  };

  LyricLine _lineFromJson(Map<String, Object?> value) => LyricLine(
    text: value['text']! as String,
    start: Duration(milliseconds: value['startMs']! as int),
    end: Duration(milliseconds: value['endMs']! as int),
    confidence: (value['confidence'] as num?)?.toDouble() ?? .5,
    vocalRole:
        VocalRole.values
            .where((e) => e.name == value['vocalRole'])
            .firstOrNull ??
        VocalRole.lead,
    provenance: TimingProvenance.values.byName(
      value['provenance'] as String? ?? TimingProvenance.estimated.name,
    ),
    words: (value['words'] as List).whereType<Map>().map((raw) {
      final word = Map<String, Object?>.from(raw);
      return LyricWord(
        text: word['text']! as String,
        start: Duration(milliseconds: word['startMs']! as int),
        end: Duration(milliseconds: word['endMs']! as int),
        confidence: (word['confidence'] as num?)?.toDouble() ?? .5,
        provenance: TimingProvenance.values.byName(
          word['provenance'] as String? ?? TimingProvenance.estimated.name,
        ),
      );
    }).toList(),
  );

  String _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
