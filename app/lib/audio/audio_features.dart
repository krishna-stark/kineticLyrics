class AudioFeatures {
  const AudioFeatures({
    this.waveform = const [],
    this.spectrum = const [],
    this.energy = 0,
    this.bass = 0,
    this.mid = 0,
    this.treble = 0,
    this.onset = 0,
    this.bassOnset = 0,
    this.midOnset = 0,
    this.trebleOnset = 0,
    this.rms = 0,
    this.spectralCentroid = 0,
    this.spectralFlux = 0,
    this.zeroCrossingRate = 0,
    this.timestamp = Duration.zero,
    this.live = false,
  });

  final List<double> waveform;
  final List<double> spectrum;
  final double energy;
  final double bass;
  final double mid;
  final double treble;
  final double onset;
  final double bassOnset;
  final double midOnset;
  final double trebleOnset;
  final double rms;
  final double spectralCentroid;
  final double spectralFlux;
  final double zeroCrossingRate;
  final Duration timestamp;
  final bool live;

  static const silent = AudioFeatures();

  factory AudioFeatures.fromMap(Map<Object?, Object?> value) => AudioFeatures(
    waveform: _samples(value['waveform'], 64, signed: true),
    spectrum: _samples(value['spectrum'], 32),
    energy: _unit(value['energy']),
    bass: _unit(value['bass']),
    mid: _unit(value['mid']),
    treble: _unit(value['treble']),
    onset: _unit(value['onset']),
    bassOnset: _unit(value['bassOnset']),
    midOnset: _unit(value['midOnset']),
    trebleOnset: _unit(value['trebleOnset']),
    rms: _unit(value['rms']),
    spectralCentroid: _unit(value['spectralCentroid']),
    spectralFlux: _unit(value['spectralFlux'] ?? value['onset']),
    zeroCrossingRate: _unit(value['zeroCrossingRate']),
    timestamp: Duration(
      microseconds: ((value['timestampUs'] as num?)?.toInt() ?? 0),
    ),
    live: value['live'] == true,
  );

  /// Select an independent attack for a render-clock beat envelope without
  /// losing its real frame timestamp, signal energy, or availability.
  AudioFeatures copyWith({double? onset}) => AudioFeatures(
    waveform: waveform,
    spectrum: spectrum,
    energy: energy,
    bass: bass,
    mid: mid,
    treble: treble,
    onset: onset ?? this.onset,
    bassOnset: bassOnset,
    midOnset: midOnset,
    trebleOnset: trebleOnset,
    rms: rms,
    spectralCentroid: spectralCentroid,
    spectralFlux: spectralFlux,
    zeroCrossingRate: zeroCrossingRate,
    timestamp: timestamp,
    live: live,
  );

  static List<double> _samples(
    Object? value,
    int count, {
    bool signed = false,
  }) {
    if (value is! Iterable) return const [];
    return List<double>.unmodifiable(
      value.take(count).map((sample) {
        final number = sample is num ? sample.toDouble() : 0.0;
        return number.isFinite ? number.clamp(signed ? -1.0 : 0.0, 1.0) : 0.0;
      }),
    );
  }

  static double _unit(Object? value) =>
      ((value as num?)?.toDouble() ?? 0).clamp(0, 1);
}
