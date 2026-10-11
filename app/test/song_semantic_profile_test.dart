import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  test('cached semantic direction retains object and typography decisions', () {
    const profile = SongSemanticProfile(
      trackKey: 'song',
      aiGenerated: true,
      analysisMilliseconds: 180,
      songObjects: [BackgroundObjectKind.phone, BackgroundObjectKind.chain],
      lines: {
        3: LineSemanticProfile(
          lineIndex: 3,
          motionPath: SemanticMotionPath.split,
          motionConfidence: .85,
          objects: [BackgroundObjectKind.heart],
        ),
      },
    );
    final restored = SongSemanticProfile.fromJson(profile.toJson());
    expect(restored.aiGenerated, isTrue);
    expect(restored.songObjects, profile.songObjects);
    final line = restored.lineAt(3)!;
    expect(line.typography, SemanticTypography.elegant);
    expect(line.composition, SemanticComposition.paired);
    expect(line.transition, SemanticTransition.lift);
    expect(line.objects, [BackgroundObjectKind.heart]);
    expect(restored.lineAt(0), isNull);
  });

  test('intensity and stillness produce different coherent direction', () {
    const impact = LineSemanticProfile(
      lineIndex: 0,
      motionPath: SemanticMotionPath.tunnel,
      motionConfidence: .9,
    );
    const quiet = LineSemanticProfile(
      lineIndex: 1,
      motionPath: SemanticMotionPath.stillness,
      motionConfidence: .9,
    );
    expect(impact.typography, SemanticTypography.display);
    expect(impact.transition, SemanticTransition.impact);
    expect(quiet.typography, SemanticTypography.soft);
    expect(quiet.transition, SemanticTransition.dissolve);
  });
}
