import 'dart:math' as math;
import '../audio/audio_features.dart';

/// Real spectral onsets only: fast attack, short release, no synthetic BPM.
/// The render clock advances the envelope, independent of native frame rate.
class BeatEnvelope {
  BeatEnvelope({this.decaySeconds = .13, this.refractorySeconds = .14})
    : assert(decaySeconds > 0),
      assert(refractorySeconds >= 0);

  final double decaySeconds;
  final double refractorySeconds;
  double strength = 0;
  double age = 1;
  double _sinceHit = 1;
  double _previousOnset = 0;
  double _floor = .02;
  Duration? _timestamp;

  void update(AudioFeatures frame, double delta) {
    final dt = delta.clamp(0.0, .1);
    age += dt;
    _sinceHit += dt;
    strength *= math.exp(-dt / decaySeconds);
    if (!frame.live) {
      reset();
      return;
    }
    if (_timestamp == frame.timestamp) return;
    _timestamp = frame.timestamp;
    if (frame.onset >= math.max(.06, _floor * 1.6) &&
        frame.onset > _previousOnset + .02 &&
        _sinceHit >= refractorySeconds &&
        frame.energy > .025) {
      strength = math.max(.35, frame.onset);
      age = 0;
      _sinceHit = 0;
    }
    _previousOnset = frame.onset;
    _floor = _floor * .95 + frame.onset * .05;
  }

  void reset() {
    strength = 0;
    age = 1;
    _sinceHit = 1;
    _previousOnset = 0;
    _floor = .02;
    _timestamp = null;
  }
}
