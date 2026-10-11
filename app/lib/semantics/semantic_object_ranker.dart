import 'song_semantic_profile.dart';

class SemanticObjectCandidate {
  const SemanticObjectCandidate({
    required this.kind,
    required this.similarity,
    required this.neutralSimilarity,
    this.explicitAnchor = false,
  });
  final BackgroundObjectKind kind;
  final double similarity;
  final double neutralSimilarity;
  final bool explicitAnchor;
  double get specificity => similarity - neutralSimilarity;
}

/// Object imagery needs more specific evidence than a subtle motion direction.
/// A raw cosine hub cannot beat lyric-specific evidence, and ambiguous imagery
/// is omitted instead of filling the scene with an unrelated object.
class SemanticObjectRanker {
  const SemanticObjectRanker();

  List<BackgroundObjectKind> select(
    List<SemanticObjectCandidate> candidates, {
    int limit = 1,
    double minimumSimilarity = .81,
    double minimumSpecificity = .04,
    double minimumMargin = .008,
  }) {
    if (limit <= 0) return const [];
    final explicit =
        candidates.where((candidate) => candidate.explicitAnchor).toList()
          ..sort((a, b) => b.specificity.compareTo(a.specificity));
    // A complete native-script/English word in the lyric is direct grounding;
    // it takes precedence even when cross-language embedding strength is weak.
    if (explicit.isNotEmpty) {
      return explicit.take(limit).map((candidate) => candidate.kind).toList();
    }
    final ranked = candidates.toList()
      ..sort((a, b) => b.specificity.compareTo(a.specificity));
    final result = <BackgroundObjectKind>[];
    for (
      var index = 0;
      index < ranked.length && result.length < limit;
      index++
    ) {
      final candidate = ranked[index];
      if (candidate.specificity < minimumSpecificity ||
          candidate.similarity < minimumSimilarity) {
        break;
      }
      final runnerUp = index + 1 < ranked.length
          ? ranked[index + 1].specificity
          : 0.0;
      if (candidate.specificity - runnerUp < minimumMargin) break;
      result.add(candidate.kind);
    }
    return result;
  }
}
