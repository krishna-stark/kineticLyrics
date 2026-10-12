import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/semantics/on_device_semantic_analyzer.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';
import 'package:kinetic_lyrics/visuals/song_score.dart';

void main() {
  test('literal cue order is independent of object library order', () {
    final mentions = OnDeviceE5SemanticAnalyzer.lexicalMentionsFor(
      'moon and rose',
    );
    expect(mentions.map((m) => m.kind), [
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rose,
    ]);
    expect(
      OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('without a gun, a rose'),
      [BackgroundObjectKind.rose],
    );
    expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('குடை'), [
      BackgroundObjectKind.umbrella,
    ]);
    expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('దీపం'), [
      BackgroundObjectKind.candle,
    ]);
    expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('registan'), [
      BackgroundObjectKind.desert,
    ]);
  });

  test(
    'objects switch at their word onset and expire at the line boundary',
    () {
      const source = LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.wordSynced,
        lines: [
          LyricLine(
            text: 'moon and rose',
            start: Duration.zero,
            end: Duration(seconds: 5),
            words: [
              LyricWord(
                text: 'moon',
                start: Duration.zero,
                end: Duration(seconds: 1),
                provenance: TimingProvenance.provider,
              ),
              LyricWord(
                text: 'and',
                start: Duration(seconds: 1),
                end: Duration(seconds: 2),
                provenance: TimingProvenance.provider,
              ),
              LyricWord(
                text: 'rose',
                start: Duration(seconds: 2),
                end: Duration(seconds: 5),
                provenance: TimingProvenance.provider,
              ),
            ],
          ),
          LyricLine(
            text: 'stay beside me',
            start: Duration(seconds: 5),
            end: Duration(seconds: 10),
          ),
        ],
      );
      final score = SongScore.prepare(source, identity: 'test');
      expect(score.objectAt(const Duration(milliseconds: 1500)), 'moon');
      expect(score.objectAt(const Duration(milliseconds: 2500)), 'rose');
      expect(score.objectAt(const Duration(seconds: 6)), isNull);
      expect(score.objectAt(const Duration(seconds: 11)), isNull);
    },
  );
}
