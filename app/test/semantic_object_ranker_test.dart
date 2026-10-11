import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/semantics/semantic_object_ranker.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  const ranker = SemanticObjectRanker();
  test(
    'generic mirror hub loses to a grounded flame despite higher raw cosine',
    () {
      expect(
        ranker.select(const [
          SemanticObjectCandidate(
            kind: BackgroundObjectKind.mirror,
            similarity: .89,
            neutralSimilarity: .86,
          ),
          SemanticObjectCandidate(
            kind: BackgroundObjectKind.flame,
            similarity: .84,
            neutralSimilarity: .76,
          ),
        ]),
        [BackgroundObjectKind.flame],
      );
    },
  );

  test('strong but ambiguous object evidence is omitted', () {
    expect(
      ranker.select(const [
        SemanticObjectCandidate(
          kind: BackgroundObjectKind.mirror,
          similarity: .88,
          neutralSimilarity: .83,
        ),
        SemanticObjectCandidate(
          kind: BackgroundObjectKind.flame,
          similarity: .86,
          neutralSimilarity: .811,
        ),
      ]),
      isEmpty,
    );
    // A runner-up just below the specificity threshold still makes the winner
    // ambiguous; filtering it first would incorrectly approve this image.
    expect(
      ranker.select(const [
        SemanticObjectCandidate(
          kind: BackgroundObjectKind.moon,
          similarity: .85,
          neutralSimilarity: .809,
        ),
        SemanticObjectCandidate(
          kind: BackgroundObjectKind.sun,
          similarity: .84,
          neutralSimilarity: .801,
        ),
      ]),
      isEmpty,
    );
  });

  test(
    'explicit native anchor survives weak embeddings and wins over generic imagery',
    () {
      expect(
        ranker.select(const [
          SemanticObjectCandidate(
            kind: BackgroundObjectKind.mirror,
            similarity: .9,
            neutralSimilarity: .8,
          ),
          SemanticObjectCandidate(
            kind: BackgroundObjectKind.lotus,
            similarity: .74,
            neutralSimilarity: .76,
            explicitAnchor: true,
          ),
        ]),
        [BackgroundObjectKind.lotus],
      );
    },
  );

  test(
    'weak specificity never creates an object simply to populate the scene',
    () {
      expect(
        ranker.select(const [
          SemanticObjectCandidate(
            kind: BackgroundObjectKind.musicNote,
            similarity: .9,
            neutralSimilarity: .89,
          ),
        ]),
        isEmpty,
      );
      expect(ranker.select(const []), isEmpty);
    },
  );
}
