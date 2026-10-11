import 'audio_features.dart';

enum MusicProfile { dance, upbeat, melodic, lofi, balanced }

class MusicState {
  const MusicState({
    required this.features,
    required this.profile,
    required this.sectionEnergy,
    required this.peak,
  });

  static const silent = MusicState(
    features: AudioFeatures.silent,
    profile: MusicProfile.balanced,
    sectionEnergy: 0,
    peak: false,
  );

  final AudioFeatures features;
  final MusicProfile profile;
  final double sectionEnergy;
  final bool peak;
}

/// Converts noisy FFT frames into a stable musical section. Profiles only
/// change after a candidate persists, while peaks remain responsive.
class MusicStateTracker {
  AudioFeatures _smoothed = AudioFeatures.silent;
  MusicProfile _profile = MusicProfile.balanced;
  MusicProfile? _candidate;
  int _candidateFrames = 0;
  double _sectionEnergy = 0;

  MusicState update(AudioFeatures frame) {
    if (!frame.live) {
      reset();
      return MusicState.silent;
    }
    const fast = .16;
    const slow = .025;
    _smoothed = AudioFeatures(
      waveform: frame.waveform,
      spectrum: frame.spectrum,
      energy: _mix(_smoothed.energy, frame.energy, fast),
      bass: _mix(
        _smoothed.bass,
        frame.bass,
        frame.bass > _smoothed.bass ? .5 : fast,
      ),
      mid: _mix(
        _smoothed.mid,
        frame.mid,
        frame.mid > _smoothed.mid ? .62 : .20,
      ),
      treble: _mix(
        _smoothed.treble,
        frame.treble,
        frame.treble > _smoothed.treble ? .80 : .32,
      ),
      // Preserve attacks on the first frame; smoothing only the release avoids
      // delaying short percussion hits until after the audible beat.
      onset: frame.onset > _smoothed.onset
          ? frame.onset
          : _mix(_smoothed.onset, frame.onset, .28),
      bassOnset: _attack(_smoothed.bassOnset, frame.bassOnset, .24),
      midOnset: _attack(_smoothed.midOnset, frame.midOnset, .32),
      trebleOnset: _attack(_smoothed.trebleOnset, frame.trebleOnset, .48),
      rms: _mix(_smoothed.rms, frame.rms, fast),
      spectralCentroid: _mix(
        _smoothed.spectralCentroid,
        frame.spectralCentroid,
        fast,
      ),
      spectralFlux: _mix(_smoothed.spectralFlux, frame.spectralFlux, .28),
      zeroCrossingRate: _mix(
        _smoothed.zeroCrossingRate,
        frame.zeroCrossingRate,
        fast,
      ),
      timestamp: frame.timestamp,
      live: true,
    );
    _sectionEnergy = _mix(_sectionEnergy, frame.energy, slow);
    final next = classify(_smoothed, sectionEnergy: _sectionEnergy);
    if (next == _profile) {
      _candidate = null;
      _candidateFrames = 0;
    } else if (next == _candidate) {
      _candidateFrames++;
      if (_candidateFrames >= 36) {
        _profile = next;
        _candidate = null;
        _candidateFrames = 0;
      }
    } else {
      _candidate = next;
      _candidateFrames = 1;
    }
    final peakThreshold = (_sectionEnergy + .24).clamp(.48, .82);
    return MusicState(
      features: _smoothed,
      profile: _profile,
      sectionEnergy: _sectionEnergy,
      peak: frame.onset > .72 && frame.energy > peakThreshold,
    );
  }

  void reset() {
    _smoothed = AudioFeatures.silent;
    _profile = MusicProfile.balanced;
    _candidate = null;
    _candidateFrames = 0;
    _sectionEnergy = 0;
  }

  static MusicProfile classify(AudioFeatures audio, {double? sectionEnergy}) {
    if (!audio.live) return MusicProfile.balanced;
    final energy = sectionEnergy ?? audio.energy;
    if (energy < .22 && audio.onset < .36 && audio.treble < .44) {
      return MusicProfile.lofi;
    }
    if (audio.bass > .5 && audio.bass > audio.mid * 1.08) {
      return MusicProfile.dance;
    }
    if (energy > .53 || audio.onset > .6 || audio.treble > .66) {
      return MusicProfile.upbeat;
    }
    if (audio.mid > audio.bass * .94 && audio.onset < .5) {
      return MusicProfile.melodic;
    }
    return MusicProfile.balanced;
  }

  static double _attack(double from, double to, double release) =>
      to > from ? to : _mix(from, to, release);

  static double _mix(double from, double to, double amount) =>
      from + (to - from) * amount;
}
