import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/semantics/semantic_direction_ranker.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  const ranker = SemanticDirectionRanker();
  test('generic wave hub does not defeat a more specific rising lyric', () {
    final direction = ranker.rank(
      {SemanticMotionPath.wave: .84, SemanticMotionPath.rise: .80},
      {SemanticMotionPath.wave: .83, SemanticMotionPath.rise: .75},
    );
    expect(direction.path, SemanticMotionPath.rise);
    expect(direction.relativeScore, closeTo(.02, .000001));
    expect(direction.confidence, greaterThan(.65));
  });

  test('lyric-dependent relative evidence selects distinct meanings', () {
    const baseline = {
      SemanticMotionPath.wave: .83,
      SemanticMotionPath.rise: .75,
      SemanticMotionPath.scatter: .74,
    };
    final rising = ranker.rank({
      SemanticMotionPath.wave: .84,
      SemanticMotionPath.rise: .81,
      SemanticMotionPath.scatter: .75,
    }, baseline);
    final breaking = ranker.rank({
      SemanticMotionPath.wave: .84,
      SemanticMotionPath.rise: .76,
      SemanticMotionPath.scatter: .80,
    }, baseline);
    expect(rising.path, SemanticMotionPath.rise);
    expect(breaking.path, SemanticMotionPath.scatter);
    expect(rising.confidence, greaterThan(.65));
    expect(breaking.confidence, greaterThan(.65));
  });

  test('neutral and tied evidence cannot invent confident motion', () {
    const baseline = {
      SemanticMotionPath.wave: .83,
      SemanticMotionPath.rise: .75,
    };
    expect(ranker.rank(baseline, baseline).confidence, 0);
    final tied = ranker.rank({
      SemanticMotionPath.wave: .84,
      SemanticMotionPath.rise: .76,
    }, baseline);
    expect(tied.confidence, lessThan(.65));
  });

  test(
    'song objects require recurring lyric evidence, not one-off imagery',
    () {
      LineSemanticProfile line(int index, List<BackgroundObjectKind> objects) =>
          LineSemanticProfile(
            lineIndex: index,
            motionPath: SemanticMotionPath.wave,
            motionConfidence: .8,
            objects: objects,
          );
      expect(
        ranker.recurringObjects([
          line(0, [BackgroundObjectKind.moon]),
          line(1, [BackgroundObjectKind.lightning]),
          line(2, [BackgroundObjectKind.moon]),
          line(3, [BackgroundObjectKind.stars, BackgroundObjectKind.stars]),
        ]),
        [BackgroundObjectKind.moon],
      );
      expect(
        ranker.recurringObjects([
          line(0, [BackgroundObjectKind.brokenGlass]),
        ]),
        isEmpty,
      );
    },
  );
}
