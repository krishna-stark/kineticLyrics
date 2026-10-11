import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/visuals/lyric_scene.dart';
import 'package:kinetic_lyrics/visuals/word_choreography.dart';

WordPose sample(
  double age, {
  int index = 1,
  LyricMood mood = LyricMood.heavy,
}) => WordPose.sample(
  mood: mood,
  index: index,
  count: 5,
  age: age,
  phraseDuration: 5000,
  wordStart: 1000,
  wordDuration: 700,
);

void main() {
  test('upcoming words stay readable, then turn in and settle', () {
    expect(sample(500).opacity, greaterThan(.3));
    expect(sample(1040).turnY.abs(), greaterThan(.4));
    expect(sample(1040).scale, lessThan(.9));
    final held = sample(2000);
    expect(held.opacity, 1);
    expect(held.scale, 1);
    expect(held.offset.distance, 0);
    expect(held.turnX, 0);
    expect(held.turnY, 0);
    expect(sample(3000).offset, held.offset);
  });
  test('word exits stagger, turn away and finish invisible', () {
    expect(
      sample(4870, index: 0).opacity,
      lessThan(sample(4870, index: 4).opacity),
    );
    expect(sample(4900).turnX, greaterThan(0));
    expect(sample(4900).offset.distance, greaterThan(0));
    expect(sample(5000).opacity, 0);
  });
  test(
    'word motion stays inside its reserved travel budget for every mood',
    () {
      for (final mood in LyricMood.values) {
        for (var age = 0.0; age <= 5000; age += 25) {
          final pose = sample(age, mood: mood);
          expect(pose.offset.dx.abs(), lessThanOrEqualTo(5));
          expect(pose.offset.dy.abs(), lessThanOrEqualTo(10));
          expect(pose.scale, lessThanOrEqualTo(1));
          expect(pose.opacity, inInclusiveRange(0, 1));
        }
      }
    },
  );
}
