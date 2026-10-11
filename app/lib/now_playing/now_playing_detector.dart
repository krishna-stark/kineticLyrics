import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'now_playing_snapshot.dart';

abstract interface class NowPlayingDetector {
  Stream<NowPlayingSnapshot> get snapshots;
  Future<void> openAccessSettings();
  Future<void> refresh();
  void dispose();

  factory NowPlayingDetector.forCurrentPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidNowPlayingDetector();
    }
    return UnsupportedNowPlayingDetector(defaultTargetPlatform.name);
  }
}

final class AndroidNowPlayingDetector implements NowPlayingDetector {
  static const _methods = MethodChannel('kinetic_lyrics/now_playing/methods');
  static const _events = EventChannel('kinetic_lyrics/now_playing/events');

  Stream<NowPlayingSnapshot>? _snapshots;

  @override
  Stream<NowPlayingSnapshot> get snapshots => _snapshots ??= _events
      .receiveBroadcastStream()
      .map(
        (event) => NowPlayingSnapshot.fromMap(event as Map<Object?, Object?>),
      )
      .distinct();

  @override
  Future<void> openAccessSettings() =>
      _methods.invokeMethod('openAccessSettings');

  @override
  Future<void> refresh() => _methods.invokeMethod('refresh');

  @override
  void dispose() {}
}

final class UnsupportedNowPlayingDetector implements NowPlayingDetector {
  UnsupportedNowPlayingDetector(this.platformName);

  final String platformName;

  @override
  Stream<NowPlayingSnapshot> get snapshots => Stream.value(
    NowPlayingSnapshot(
      access: NowPlayingAccess.unsupported,
      message: 'The $platformName adapter has not been implemented yet.',
    ),
  );

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<void> refresh() async {}

  @override
  void dispose() {}
}
