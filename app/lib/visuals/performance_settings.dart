enum PerformanceIntensity { subtle, cinematic, concert }

enum VocalLayout { automatic, callAndResponse }

class PerformanceSettings {
  const PerformanceSettings({
    this.intensity = PerformanceIntensity.cinematic,
    this.haptics = false,
    this.reduceMotion = false,
    this.vocalLayout = VocalLayout.automatic,
  });

  final PerformanceIntensity intensity;
  final bool haptics;
  final bool reduceMotion;
  final VocalLayout vocalLayout;

  double get motion => switch (intensity) {
    PerformanceIntensity.subtle => .45,
    PerformanceIntensity.cinematic => .8,
    PerformanceIntensity.concert => 1.0,
  };

  PerformanceSettings copyWith({
    PerformanceIntensity? intensity,
    bool? haptics,
    bool? reduceMotion,
    VocalLayout? vocalLayout,
  }) => PerformanceSettings(
    intensity: intensity ?? this.intensity,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    vocalLayout: vocalLayout ?? this.vocalLayout,
  );

  Map<String, Object> toJson() => {
    'intensity': intensity.name,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'vocalLayout': vocalLayout.name,
  };

  factory PerformanceSettings.fromJson(Map<String, Object?> json) {
    return PerformanceSettings(
      intensity:
          PerformanceIntensity.values
              .where((e) => e.name == json['intensity'])
              .firstOrNull ??
          PerformanceIntensity.cinematic,
      vocalLayout:
          VocalLayout.values
              .where((e) => e.name == json['vocalLayout'])
              .firstOrNull ??
          VocalLayout.automatic,
      haptics: json['haptics'] == true,
      reduceMotion: json['reduceMotion'] == true,
    );
  }
}

/// Sparse measured bass accents, never a synthetic timer or every frame.
class HapticAccentGate {
  Duration? _lastEvent;
  Duration? _lastPulse;
  bool accept({
    required Duration timestamp,
    required Duration playback,
    required double attack,
    required double energy,
  }) {
    if (_lastEvent == timestamp) return false;
    _lastEvent = timestamp;
    if (_lastPulse != null && playback < _lastPulse!) _lastPulse = null;
    if (attack < .45 ||
        energy < .15 ||
        (_lastPulse != null &&
            playback - _lastPulse! < const Duration(milliseconds: 600))) {
      return false;
    }
    _lastPulse = playback;
    return true;
  }

  void reset() {
    _lastEvent = null;
    _lastPulse = null;
  }
}
