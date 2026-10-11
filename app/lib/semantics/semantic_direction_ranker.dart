import 'song_semantic_profile.dart';

/// Removes each prototype's attraction to generic lyric wording before ranking
/// a particular lyric. Per-query centering alone cannot change a ranking; the
/// prototype-specific neutral baseline is the important hub-bias correction.
class SemanticDirectionRanker {
  const SemanticDirectionRanker();

  ({SemanticMotionPath path, double relativeScore, double confidence}) rank(
    Map<SemanticMotionPath, double> similarities,
    Map<SemanticMotionPath, double> neutralBaseline,
  ) {
    if (similarities.isEmpty) {
      return (
        path: SemanticMotionPath.stillness,
        relativeScore: 0,
        confidence: 0,
      );
    }
    final adjusted = {
      for (final entry in similarities.entries)
        entry.key: entry.value - (neutralBaseline[entry.key] ?? 0),
    };
    final mean = adjusted.values.reduce((a, b) => a + b) / adjusted.length;
    final ranked = adjusted.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : best.value;
    final margin = best.value - second;
    // A relative separation measure, not a probability. Ambiguous equal scores
    // stay below the renderer's threshold rather than inventing varied motion.
    final confidence = best.value <= 0
        ? 0.0
        : (.5 + .5 * (margin / .025).clamp(0, 1));
    return (
      path: best.key,
      relativeScore: best.value - mean,
      confidence: confidence,
    );
  }

  List<BackgroundObjectKind> recurringObjects(
    Iterable<LineSemanticProfile> lines, {
    int limit = 2,
  }) {
    final frequency = <BackgroundObjectKind, int>{};
    for (final line in lines) {
      for (final object in line.objects.toSet()) {
        frequency.update(object, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final recurring =
        frequency.entries.where((entry) => entry.value >= 2).toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
          });
    return recurring.take(limit).map((entry) => entry.key).toList();
  }
}
