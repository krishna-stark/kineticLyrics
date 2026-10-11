import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/audio/music_state.dart';
import 'package:kinetic_lyrics/visuals/beat_envelope.dart';
import 'package:kinetic_lyrics/visuals/context_asset_store.dart';

AudioFeatures frame(int ms, double onset, {bool live = true}) => AudioFeatures(
  onset: onset,
  energy: .6,
  timestamp: Duration(milliseconds: ms),
  live: live,
);

void main() {
  test(
    'context objects follow actual lyric cues and unknowns stay abstract',
    () {
      expect(ContextAssetStore.select('You call me again'), 'phone');
      expect(ContextAssetStore.select('I am letting go'), 'chain');
      expect(ContextAssetStore.select('Walk out the door'), 'door');
      expect(ContextAssetStore.select('Feel the fire inside'), 'flame');
      expect(ContextAssetStore.select('ప్రేమ నీతో'), 'heart');
      expect(ContextAssetStore.select('unfamiliar phrase'), isNull);
    },
  );
  test('percussion attack survives smoothing on the first audio frame', () {
    final tracker = MusicStateTracker();
    tracker.update(frame(0, 0));
    expect(tracker.update(frame(33, .9)).features.onset, .9);
    expect(tracker.update(frame(66, 0)).features.onset, lessThan(.9));
  });

  test('a real onset attacks immediately and decays without repeated hits', () {
    final envelope = BeatEnvelope();
    envelope.update(frame(0, .8), 1 / 60);
    expect(envelope.strength, .8);
    expect(envelope.age, 0);
    for (var i = 0; i < 18; i++) {
      envelope.update(frame(0, .8), 1 / 60);
    }
    expect(envelope.strength, lessThan(.1));
    expect(envelope.age, closeTo(.3, .001));
    envelope.update(frame(300, 0), 1 / 60);
    envelope.update(frame(333, .9), 1 / 60);
    expect(envelope.strength, .9);
    expect(envelope.age, 0);
  });

  test('high band resolves repeated ninety millisecond attacks', () {
    final high = BeatEnvelope(decaySeconds: .065, refractorySeconds: .03);
    final low = BeatEnvelope(decaySeconds: .18, refractorySeconds: .1);
    high.update(frame(0, .8), .01);
    low.update(frame(0, .8), .01);
    high.update(frame(30, 0), .03);
    low.update(frame(30, 0), .03);
    high.update(frame(60, 0), .03);
    low.update(frame(60, 0), .03);
    high.update(frame(90, .9), .03);
    low.update(frame(90, .9), .03);
    expect(high.strength, .9);
    expect(high.age, 0);
    expect(low.age, closeTo(.09, .001));
    expect(low.strength, lessThan(.8));
  });

  test('unavailable audio clears hits rather than inventing a rhythm', () {
    final envelope = BeatEnvelope()..update(frame(0, 1), .016);
    envelope.update(AudioFeatures.silent, .016);
    expect(envelope.strength, 0);
    for (var i = 0; i < 120; i++) {
      envelope.update(AudioFeatures.silent, .016);
    }
    expect(envelope.strength, 0);
  });
}
