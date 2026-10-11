enum PlaybackStatus {
  none,
  stopped,
  paused,
  playing,
  buffering,
  connecting,
  seeking,
  error;

  String get label => switch (this) {
    PlaybackStatus.none => 'idle',
    PlaybackStatus.stopped => 'stopped',
    PlaybackStatus.paused => 'paused',
    PlaybackStatus.playing => 'live',
    PlaybackStatus.buffering => 'buffering',
    PlaybackStatus.connecting => 'connecting',
    PlaybackStatus.seeking => 'seeking',
    PlaybackStatus.error => 'error',
  };
}

class NowPlayingTrack {
  NowPlayingTrack({
    required this.sourcePackage,
    required this.sourceName,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.position,
    required this.playbackSpeed,
    required this.state,
    required this.receivedAt,
  });

  factory NowPlayingTrack.fromMap(Map<Object?, Object?> map) {
    Duration? duration;
    final durationMs = map['durationMs'] as int?;
    if (durationMs != null && durationMs > 0) {
      duration = Duration(milliseconds: durationMs);
    }

    final stateName = map['state'] as String? ?? 'none';
    return NowPlayingTrack(
      sourcePackage: map['sourcePackage'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? 'Unknown player',
      title: map['title'] as String? ?? 'Unknown track',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String?,
      duration: duration,
      position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 0,
      state: PlaybackStatus.values.firstWhere(
        (value) => value.name == stateName,
        orElse: () => PlaybackStatus.none,
      ),
      receivedAt: DateTime.now(),
    );
  }

  final String sourcePackage;
  final String sourceName;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final Duration position;
  final double playbackSpeed;
  final PlaybackStatus state;
  final DateTime receivedAt;

  bool get isAdvancing => state == PlaybackStatus.playing && playbackSpeed != 0;

  Duration positionAt(DateTime now) {
    if (!isAdvancing) return _clamp(position);
    final elapsedMs = now.difference(receivedAt).inMilliseconds;
    final extrapolated =
        position + Duration(milliseconds: (elapsedMs * playbackSpeed).round());
    return _clamp(extrapolated);
  }

  Duration _clamp(Duration value) {
    if (value.isNegative) return Duration.zero;
    if (duration != null && value > duration!) return duration!;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is NowPlayingTrack &&
      other.sourcePackage == sourcePackage &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.duration == duration &&
      other.position == position &&
      other.playbackSpeed == playbackSpeed &&
      other.state == state;

  @override
  int get hashCode => Object.hash(
    sourcePackage,
    title,
    artist,
    album,
    duration,
    position,
    playbackSpeed,
    state,
  );
}
