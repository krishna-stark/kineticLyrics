import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import '../now_playing/now_playing_track.dart';

/// Counts completed listening, not skips, seeks or metadata refreshes.
class SongAdCadence {
  SongAdCadence({this.completed = 0});
  int completed;
  String? _identity;
  NowPlayingTrack? _last;
  DateTime? _observed;
  Duration _listened = Duration.zero;
  bool _counted = false;
  bool get due => completed >= 5;
  void consumed() => completed = (completed - 5).clamp(0, 5);
  void observe(NowPlayingTrack? track, DateTime now) {
    final last = _last;
    final identity = track == null
        ? null
        : '${track.sourcePackage}/${track.title}/${track.artist}';
    if (last != null && _observed != null && last.isAdvancing) {
      final elapsed = now.difference(_observed!);
      if (elapsed > Duration.zero && elapsed <= const Duration(seconds: 3)) {
        _listened += elapsed;
      }
    }
    void finish(NowPlayingTrack candidate) {
      final duration = candidate.duration;
      if (!_counted &&
          duration != null &&
          duration > const Duration(seconds: 20) &&
          _listened >= const Duration(seconds: 15) &&
          candidate.positionAt(now) >= duration - const Duration(seconds: 2)) {
        completed = (completed + 1).clamp(0, 5);
        _counted = true;
      }
    }

    if (identity != _identity) {
      if (last != null) finish(last);
      _identity = identity;
      _listened = Duration.zero;
      _counted = false;
    } else if (track != null) {
      if (_counted && track.positionAt(now) < const Duration(seconds: 3)) {
        _counted = false;
        _listened = Duration.zero;
      }
      // A seek to the end must not count as completion.
      final continuous =
          last == null ||
          (track.positionAt(now) - last.positionAt(now)).abs() <
              const Duration(seconds: 3);
      if (continuous) {
        finish(track);
      } else {
        _listened = Duration.zero;
      }
    }
    _last = track;
    _observed = now;
  }
}

class SongAds extends ChangeNotifier {
  static const testMode = bool.fromEnvironment(
    'ADS_TEST_MODE',
    defaultValue: true,
  );
  static const _productionBanner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _productionVideo = String.fromEnvironment('ADMOB_VIDEO_ID');
  static String get bannerId =>
      testMode ? 'ca-app-pub-3940256099942544/6300978111' : _productionBanner;
  static String get videoId =>
      testMode ? 'ca-app-pub-3940256099942544/8691691433' : _productionVideo;
  final cadence = SongAdCadence();
  BannerAd? banner;
  InterstitialAd? _video;
  bool bannerReady = false, privacyRequired = false;
  bool _disposed = false, _ready = false, _loading = false, _showing = false;
  Timer? _retry, _bannerRetry;
  int _epoch = 0;
  DateTime? _videoLoadedAt;
  Future<void> _writes = Future.value();
  File? _state;
  bool get supported => !kIsWeb && Platform.isAndroid;
  Future<void> initialize() async {
    if (!supported ||
        (!testMode &&
            (bannerId.isEmpty ||
                videoId.isEmpty ||
                bannerId.contains('3940256099942544') ||
                videoId.contains('3940256099942544')))) {
      return;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      _state = File('${dir.path}/ad_cadence.json');
      if (await _state!.exists()) {
        final saved =
            jsonDecode(await _state!.readAsString()) as Map<String, dynamic>;
        cadence.completed = (saved['completed'] as int? ?? 0).clamp(0, 5);
      }
    } catch (_) {
      /* Session cadence remains available. */
    }
    if (_disposed) return;
    if (!testMode) {
      final update = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => update.complete(),
        (_) => update.complete(),
      );
      await update.future;
      if (_disposed) return;
      final form = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((_) => form.complete());
      await form.future;
      privacyRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!await ConsentInformation.instance.canRequestAds() || _disposed) {
        return;
      }
    }
    await MobileAds.instance.initialize();
    if (_disposed) return;
    _ready = true;
    _loadBanner();
    _loadVideo();
    notifyListeners();
  }

  void _loadBanner() {
    if (_disposed || !_ready || banner != null) return;
    final epoch = _epoch;
    banner = BannerAd(
      adUnitId: bannerId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_disposed || epoch != _epoch || !_ready) {
            ad.dispose();
            return;
          }
          bannerReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (_disposed || epoch != _epoch) return;
          banner = null;
          _bannerRetry?.cancel();
          _bannerRetry = Timer(const Duration(seconds: 45), _loadBanner);
        },
      ),
    );
    banner!.load();
  }

  void _loadVideo() {
    if (_disposed ||
        !_ready ||
        _loading ||
        _video != null ||
        _retry?.isActive == true) {
      return;
    }
    final epoch = _epoch;
    _loading = true;
    InterstitialAd.load(
      adUnitId: videoId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (epoch == _epoch) _loading = false;
          if (_disposed || epoch != _epoch || !_ready) {
            ad.dispose();
            return;
          }
          _video = ad;
          _videoLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (_) {
          if (_disposed || epoch != _epoch) return;
          _loading = false;
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 45), () {
            _retry = null;
            _loadVideo();
          });
        },
      ),
    );
  }

  void observe(NowPlayingTrack? track) {
    final before = cadence.completed;
    cadence.observe(track, DateTime.now());
    if (before != cadence.completed) _persist();
  }

  void _persist() {
    final file = _state;
    final count = cadence.completed;
    if (file == null) return;
    _writes = _writes
        .then((_) async {
          final pending = File('${file.path}.tmp');
          await pending.writeAsString(
            jsonEncode({'completed': count}),
            flush: true,
          );
          await pending.rename(file.path);
        })
        .catchError((_) {});
  }

  void maybeShow({
    required bool foreground,
    required bool menuOpen,
    required NowPlayingTrack? track,
  }) {
    if (_disposed ||
        _showing ||
        !foreground ||
        menuOpen ||
        !cadence.due ||
        track == null ||
        !{
          PlaybackStatus.paused,
          PlaybackStatus.stopped,
        }.contains(track.state)) {
      return;
    }
    if (_videoLoadedAt != null &&
        DateTime.now().difference(_videoLoadedAt!) >=
            const Duration(minutes: 55)) {
      _video?.dispose();
      _video = null;
    }
    final ad = _video;
    if (ad == null) {
      _loadVideo();
      return;
    }
    _video = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        cadence.consumed();
        _persist();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _loadVideo();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showing = false;
        _retry?.cancel();
        _retry = Timer(const Duration(seconds: 45), () {
          _retry = null;
          _loadVideo();
        });
      },
    );
    unawaited(
      ad.show().catchError((_) {
        ad.dispose();
        _showing = false;
        _loadVideo();
      }),
    );
  }

  Future<void> privacyOptions() async {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    await done.future;
    if (_disposed) return;
    _epoch++;
    _loading = false;
    _retry?.cancel();
    _bannerRetry?.cancel();
    _video?.dispose();
    _video = null;
    banner?.dispose();
    banner = null;
    bannerReady = false;
    _ready = await ConsentInformation.instance.canRequestAds();
    if (_ready) {
      _loadBanner();
      _loadVideo();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _bannerRetry?.cancel();
    banner?.dispose();
    _video?.dispose();
    super.dispose();
  }
}

class PausedAdSlot extends StatelessWidget {
  const PausedAdSlot({super.key, required this.ads});
  final SongAds ads;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'ADVERTISEMENT',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 9,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 300,
        height: 250,
        child:
            ads.bannerReady &&
                ads.banner != null &&
                MediaQuery.sizeOf(context).width >= 332
            ? AdWidget(ad: ads.banner!)
            : const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xff111111),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Center(
                  child: Text(
                    'Ad space',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ),
              ),
      ),
    ],
  );
}
