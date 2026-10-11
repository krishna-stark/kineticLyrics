import 'now_playing_track.dart';

enum NowPlayingAccess { checking, granted, denied, unsupported, error }

class NowPlayingSnapshot {
  const NowPlayingSnapshot({required this.access, this.track, this.message});

  factory NowPlayingSnapshot.checking() => const NowPlayingSnapshot(
    access: NowPlayingAccess.checking,
    message: 'Checking media access…',
  );

  factory NowPlayingSnapshot.fromMap(Map<Object?, Object?> map) {
    final accessName = map['access'] as String? ?? 'error';
    final trackValue = map['track'];
    return NowPlayingSnapshot(
      access: NowPlayingAccess.values.firstWhere(
        (value) => value.name == accessName,
        orElse: () => NowPlayingAccess.error,
      ),
      track: trackValue is Map
          ? NowPlayingTrack.fromMap(Map<Object?, Object?>.from(trackValue))
          : null,
      message: map['message'] as String?,
    );
  }

  final NowPlayingAccess access;
  final NowPlayingTrack? track;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is NowPlayingSnapshot &&
      other.access == access &&
      other.track == track &&
      other.message == message;

  @override
  int get hashCode => Object.hash(access, track, message);
}
