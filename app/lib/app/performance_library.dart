import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../visuals/lyric_scene.dart';
import '../visuals/performance_settings.dart';

class LyricMoment {
  const LyricMoment({
    required this.identity,
    required this.title,
    required this.artist,
    required this.line,
    required this.mood,
    required this.section,
    required this.fontSeed,
    this.object,
    this.typographyMood,
  });
  final String identity, title, artist;
  final LyricLine line;
  final LyricMood mood;
  final SongSection section;
  final int fontSeed;
  final String? object;
  final LyricMood? typographyMood;
  String get key => '$identity/${line.start.inMilliseconds}/${line.text}';
  LyricScene get scene => LyricScene(
    line,
    0,
    mood,
    0,
    refrain: section == SongSection.refrain,
    section: section,
    fontSeed: fontSeed,
    vocalRole: line.vocalRole,
    directed: true,
    typographyMood: typographyMood,
  );

  Map<String, Object?> toJson() => {
    'identity': identity,
    'title': title,
    'artist': artist,
    'text': line.text,
    'start': line.start.inMilliseconds,
    'end': line.end.inMilliseconds,
    'mood': mood.name,
    'section': section.name,
    'fontSeed': fontSeed,
    'object': object,
    'role': line.vocalRole.name,
    'typographyMood': typographyMood?.name,
    'provenance': line.provenance.name,
    'confidence': line.confidence,
    'words': line.words
        .map(
          (w) => {
            'text': w.text,
            'start': w.start.inMilliseconds,
            'end': w.end.inMilliseconds,
            'confidence': w.confidence,
            'provenance': w.provenance.name,
            'stress': w.stress,
          },
        )
        .toList(),
  };
  factory LyricMoment.fromJson(Map<String, Object?> value) {
    final start = value['start'] as int, end = value['end'] as int;
    final text = value['text'] as String;
    if (start < 0 || end <= start || text.isEmpty || text.length > 8000) {
      throw const FormatException('Invalid moment');
    }
    return LyricMoment(
      identity: value['identity'] as String,
      title: value['title'] as String,
      artist: value['artist'] as String,
      mood: LyricMood.values.byName(value['mood'] as String),
      section: SongSection.values.byName(value['section'] as String),
      fontSeed: value['fontSeed'] as int,
      object: value['object'] as String?,
      typographyMood: LyricMood.values
          .where((v) => v.name == value['typographyMood'])
          .firstOrNull,
      line: LyricLine(
        text: text,
        start: Duration(milliseconds: start),
        end: Duration(milliseconds: end),
        confidence: (value['confidence'] as num?)?.toDouble() ?? .5,
        provenance: TimingProvenance.values.byName(
          value['provenance'] as String? ?? 'estimated',
        ),
        vocalRole: VocalRole.values.byName(value['role'] as String? ?? 'lead'),
        words: (value['words'] as List)
            .whereType<Map>()
            .map(
              (v) => LyricWord(
                text: v['text'] as String,
                start: Duration(milliseconds: v['start'] as int),
                end: Duration(milliseconds: v['end'] as int),
                confidence: (v['confidence'] as num).toDouble(),
                provenance: TimingProvenance.values.byName(
                  v['provenance'] as String,
                ),
                stress: (v['stress'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Local, serialized atomic writes. No persistence or decoding on audio ticks.
class PerformanceLibrary extends ChangeNotifier {
  PerformanceLibrary({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;
  PerformanceSettings settings = const PerformanceSettings();
  List<LyricMoment> _moments = [];
  List<LyricMoment> get moments => List.unmodifiable(_moments);
  Future<void> _writes = Future.value();
  int _revision = 0;
  bool _disposed = false;
  bool storageFailed = false;
  Future<void> load() async {
    final revision = _revision;
    try {
      final root = await _directory();
      final file = File('${root.path}/performance-library-v1.json');
      if (!await file.exists() || await file.length() > 2 * 1024 * 1024) return;
      final value =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (_disposed || revision != _revision) return;
      settings = PerformanceSettings.fromJson(
        (value['settings'] as Map).cast<String, Object?>(),
      );
      _moments = (value['moments'] as List)
          .take(100)
          .whereType<Map>()
          .map((v) {
            try {
              return LyricMoment.fromJson(v.cast<String, Object?>());
            } catch (_) {
              return null;
            }
          })
          .whereType<LyricMoment>()
          .toList();
      notifyListeners();
    } catch (_) {
      /* Defaults survive missing plugin or corrupt storage. */
    }
  }

  Future<void> update(PerformanceSettings value) {
    settings = value;
    return _save();
  }

  Future<void> saveMoment(LyricMoment moment) {
    _moments.removeWhere((m) => m.key == moment.key);
    _moments.insert(0, moment);
    if (_moments.length > 100) _moments.removeLast();
    return _save();
  }

  Future<void> remove(LyricMoment moment) {
    _moments.removeWhere((m) => m.key == moment.key);
    return _save();
  }

  Future<void> _save() {
    _revision++;
    final data = jsonEncode({
      'settings': settings.toJson(),
      'moments': _moments.map((m) => m.toJson()).toList(),
    });
    if (!_disposed) notifyListeners();
    final pending = _writes.then((_) async {
      try {
        final root = await _directory();
        await root.create(recursive: true);
        final file = File('${root.path}/performance-library-v1.json');
        final temporary = File('${file.path}.partial');
        await temporary.writeAsString(data, flush: true);
        await temporary.rename(file.path);
        storageFailed = false;
      } catch (_) {
        storageFailed = true;
        rethrow;
      }
    });
    _writes = pending.catchError((Object _) {});
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
