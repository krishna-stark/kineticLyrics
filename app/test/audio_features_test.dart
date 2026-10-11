import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/visuals/beat_envelope.dart';

void main() {
  test('native attacks stay independent and are constrained to unit range', () {
    final features = AudioFeatures.fromMap({
      'bassOnset': .8,
      'midOnset': .3,
      'trebleOnset': 2,
      'bass': .6,
      'energy': .5,
      'timestampUs': 1000,
      'live': true,
    });
    expect(features.bassOnset, .8);
    expect(features.midOnset, .3);
    expect(features.trebleOnset, 1);
    final selected = features.copyWith(onset: features.midOnset);
    expect(selected.onset, .3);
    expect(selected.bassOnset, .8);
    expect(selected.bass, .6);
    expect(selected.timestamp, const Duration(microseconds: 1000));
    expect(selected.live, isTrue);
  });

  test('one band attack cannot trigger envelopes in other bands', () {
    final low = BeatEnvelope();
    final mid = BeatEnvelope();
    final high = BeatEnvelope();
    const kick = AudioFeatures(
      energy: .5,
      bass: .8,
      bassOnset: .7,
      live: true,
      timestamp: Duration(milliseconds: 30),
    );
    low.update(kick.copyWith(onset: kick.bassOnset), 1 / 60);
    mid.update(kick.copyWith(onset: kick.midOnset), 1 / 60);
    high.update(kick.copyWith(onset: kick.trebleOnset), 1 / 60);
    expect(low.strength, .7);
    expect(mid.strength, 0);
    expect(high.strength, 0);
    const hat = AudioFeatures(
      energy: .2,
      treble: .7,
      trebleOnset: .8,
      live: true,
      timestamp: Duration(milliseconds: 200),
    );
    high.update(hat.copyWith(onset: hat.trebleOnset), .1);
    expect(high.strength, .8);
  });
}
