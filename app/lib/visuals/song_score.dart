import 'dart:math' as math;
import '../lyrics/domain/lyric_timeline.dart';
import '../semantics/on_device_semantic_analyzer.dart';
import '../semantics/song_semantic_profile.dart';
import 'context_asset_store.dart';
import 'lyric_scene.dart';
import 'performance_settings.dart';

/// A bounded, deterministic lyric score. Repeated sequences are refrain cues,
/// not a claim of audio-based verse/chorus recognition.
class SongScore {
  SongScore._(this.timeline, this.scenes, this.objects);
  final LyricTimeline timeline;
  final List<LyricScene> scenes;
  final Map<int, String?> objects;

  static SongScore prepare(
    LyricTimeline source, {
    required String identity,
    SongSemanticProfile? semantic,
    List<String> songObjects = const [],
    VocalLayout vocalLayout = VocalLayout.automatic,
  }) {
    final timeline = LyricScene.readableTimeline(source);
    final base = LyricScene.prepare(timeline);
    final keys = timeline.lines.map((l) => _key(l.text)).toList();
    final repeats = List<bool>.filled(keys.length, false);
    // Match sequences, not isolated "oh" or "yeah" fillers. Bound the search
    // to two-line signatures and preserve native-script letters.
    final occurrences = <String, List<int>>{};
    for (var i = 0; i + 1 < keys.length; i++) {
      if (keys[i].length < 5 ||
          keys[i + 1].length < 5 ||
          keys[i] == keys[i + 1]) {
        continue;
      }
      final signature = '${keys[i]}\n${keys[i + 1]}';
      occurrences.putIfAbsent(signature, () => []).add(i);
    }
    for (final indices in occurrences.values) {
      if (indices.length < 2) continue;
      for (final index in indices) {
        repeats[index] = repeats[index + 1] = true;
      }
    }
    final seed = _hash(identity);
    final moodCounts = <LyricMood, int>{};
    for (final scene in base) {
      if (scene.mood != LyricMood.quiet) {
        moodCounts[scene.mood] = (moodCounts[scene.mood] ?? 0) + 1;
      }
    }
    final fastLines = base
        .where(
          (s) =>
              s.line.words.isNotEmpty &&
              (s.line.end - s.line.start).inMilliseconds / s.line.words.length <
                  300,
        )
        .length;
    final dominantMood = fastLines > base.length / 3
        ? LyricMood.urgent
        : moodCounts.isEmpty
        ? LyricMood.quiet
        : (moodCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    var block = -1;
    SongSection? last;
    final objects = <int, String?>{};
    String? held;
    Duration? heldSince;
    final scenes = <LyricScene>[];
    for (var i = 0; i < base.length; i++) {
      final scene = base[i];
      final section = !scene.hasLyrics
          ? SongSection.instrumental
          : repeats[i]
          ? SongSection.refrain
          : i == 0 && timeline.lines.length > 4
          ? SongSection.intro
          : i == base.length - 1 && base.length > 4
          ? SongSection.outro
          : SongSection.verse;
      if (section != last ||
          (i > 0 &&
              scene.line.start - base[i - 1].line.end >
                  const Duration(seconds: 2))) {
        block++;
      }
      last = section;
      final original = source.indexAt(scene.line.start);
      final meaning = semantic?.lineAt(original);
      final mood =
          scene.mood == LyricMood.quiet &&
              meaning != null &&
              meaning.motionConfidence >= .72
          ? switch (meaning.motionPath) {
              SemanticMotionPath.split => LyricMood.romantic,
              SemanticMotionPath.corner ||
              SemanticMotionPath.fall => LyricMood.lonely,
              SemanticMotionPath.tunnel ||
              SemanticMotionPath.scatter => LyricMood.heavy,
              SemanticMotionPath.rise => LyricMood.joyful,
              SemanticMotionPath.horizontal => LyricMood.urgent,
              _ => LyricMood.quiet,
            }
          : scene.mood;
      final marked = scene.line.vocalRole;
      final role = marked != VocalRole.lead
          ? marked
          : vocalLayout == VocalLayout.callAndResponse
          ? (i.isEven ? VocalRole.lead : VocalRole.response)
          : VocalRole.lead;
      scenes.add(
        LyricScene(
          scene.line,
          i,
          mood,
          scene.motif,
          refrain: repeats[i],
          recurrence: scene.recurrence,
          section: section,
          block: block,
          fontSeed: seed,
          vocalRole: role,
          directed: true,
          typographyMood: dominantMood,
        ),
      );

      final lexical = OnDeviceE5SemanticAnalyzer.lexicalObjectsFor(
        scene.line.text,
      );
      final explicit = lexical.firstOrNull?.name;
      final candidate = explicit ?? meaning?.objects.firstOrNull?.name;
      final available = ContextAssetStore.availableIds;
      final next = available.contains(candidate) ? candidate : null;
      // A literal new cue overrides immediately; ambiguous context does not
      // keep a stale prop indefinitely. Hold a verified song motif at most 12 s.
      if (next != null) {
        if (next != held) heldSince = scene.line.start;
        held = next;
      } else if (heldSince == null ||
          scene.line.start - heldSince > const Duration(seconds: 8)) {
        held = songObjects
            .where((id) => available.contains(id) && id != 'musicNote')
            .firstOrNull;
        heldSince = held == null ? null : scene.line.start;
      }
      objects[i] = scene.hasLyrics ? held : null;
    }
    return SongScore._(
      timeline,
      List.unmodifiable(scenes),
      Map.unmodifiable(objects),
    );
  }

  static String _key(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[\s,.!?;:…]+'), ' ').trim();
  static int _hash(String text) {
    var result = 0x811c9dc5;
    for (final c in text.codeUnits) {
      result = ((result ^ c) * 0x01000193) & 0x7fffffff;
    }
    return math.max(0, result);
  }
}
