import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/audio/audio_features.dart';
import 'package:kinetic_lyrics/audio/music_state.dart';

void main() {
  test('band attacks arrive immediately and release at independent rates', () {
    final tracker = MusicStateTracker();
    final attack = tracker
        .update(
          const AudioFeatures(
            bass: .8,
            mid: .7,
            treble: .9,
            bassOnset: .9,
            midOnset: .6,
            trebleOnset: .8,
            live: true,
          ),
        )
        .features;
    expect(attack.bassOnset, .9);
    expect(attack.midOnset, .6);
    expect(attack.trebleOnset, .8);
    expect(attack.mid, greaterThan(.4));
    expect(attack.treble, greaterThan(.7));
    final release = tracker.update(const AudioFeatures(live: true)).features;
    expect(release.bassOnset, closeTo(.9 * .76, .0001));
    expect(release.midOnset, closeTo(.6 * .68, .0001));
    expect(release.trebleOnset, closeTo(.8 * .52, .0001));
    final stopped = tracker.update(AudioFeatures.silent).features;
    expect(stopped.bassOnset, 0);
    expect(stopped.midOnset, 0);
    expect(stopped.trebleOnset, 0);
  });

  test('profile requires sustained evidence before it changes', () {
    final tracker = MusicStateTracker();
    const dance = AudioFeatures(
      energy: .72,
      bass: .9,
      mid: .34,
      treble: .42,
      onset: .64,
      live: true,
    );

    expect(tracker.update(dance).profile, MusicProfile.balanced);
    MusicState state = MusicState.silent;
    for (var index = 0; index < 80; index++) {
      state = tracker.update(dance);
    }
    expect(state.profile, MusicProfile.dance);
  });

  test('a single bright frame cannot flip a calm profile', () {
    final tracker = MusicStateTracker();
    const calm = AudioFeatures(
      energy: .12,
      bass: .18,
      mid: .24,
      treble: .16,
      onset: .05,
      live: true,
    );
    for (var index = 0; index < 80; index++) {
      tracker.update(calm);
    }
    expect(tracker.update(calm).profile, MusicProfile.lofi);

    const spike = AudioFeatures(
      energy: 1,
      bass: .8,
      mid: .8,
      treble: 1,
      onset: 1,
      live: true,
    );
    expect(tracker.update(spike).profile, MusicProfile.lofi);
  });
}
