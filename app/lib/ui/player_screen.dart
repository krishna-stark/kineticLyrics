import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../app/kinetic_lyrics_controller.dart';
import '../now_playing/now_playing_snapshot.dart';
import '../visuals/music_surface.dart';
import '../visuals/song_score.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../app/performance_library.dart';
import 'performance_panel.dart';
import 'playback_panel.dart';
import 'pause_stage.dart';
import '../ads/song_ads.dart';
import '../now_playing/now_playing_track.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.controller});
  final KineticLyricsController controller;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final _library = PerformanceLibrary();
  final _pages = PageController();
  final _ads = SongAds();
  Timer? _adClock;
  int _page = 0;
  bool _controlsVisible = false;
  bool _menuOpen = false;
  bool _pausedSettings = false;
  PlaybackStatus? _previousState;
  Timer? _hide;
  bool _foreground = true;
  bool _screenAwake = false;
  void _syncDisplay() {
    final state = widget.controller.snapshot.track?.state;
    if (_previousState == PlaybackStatus.paused &&
        state != PlaybackStatus.paused) {
      _controlsVisible = false;
      _pausedSettings = false;
    }
    _previousState = state;
    final awake =
        _foreground && widget.controller.snapshot.track?.isAdvancing == true;
    if (awake == _screenAwake ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _screenAwake = awake;
    unawaited(
      const MethodChannel(
        'kinetic_lyrics/now_playing/methods',
      ).invokeMethod<void>('setScreenAwake', awake).catchError((_) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    _ads.addListener(_libraryChanged);
    unawaited(_ads.initialize().catchError((_) {}));
    _adClock = Timer.periodic(const Duration(seconds: 1), (_) {
      _ads.observe(widget.controller.snapshot.track);
      _ads.maybeShow(
        foreground: _foreground,
        menuOpen:
            _menuOpen ||
            _pausedSettings ||
            (_controlsVisible &&
                widget.controller.snapshot.track?.state !=
                    PlaybackStatus.paused),
        track: widget.controller.snapshot.track,
      );
    });
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncDisplay);
    _syncDisplay();
    _library.addListener(_libraryChanged);
    unawaited(_library.load());
  }

  void _libraryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hide?.cancel();
    _adClock?.cancel();
    _ads.removeListener(_libraryChanged);
    _ads.dispose();
    _pages.dispose();
    _library.removeListener(_libraryChanged);
    _library.dispose();
    widget.controller.removeListener(_syncDisplay);
    _foreground = false;
    _syncDisplay();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncDisplay();
    if (state == AppLifecycleState.resumed) {
      unawaited(_action(widget.controller.refresh));
    }
  }

  void _showControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _hide?.cancel();
    if (_controlsVisible) {
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  void _closeControls() => setState(() => _controlsVisible = false);
  void _settings() => _pages.animateToPage(
    1,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  Future<void> _performance() async {
    _hide?.cancel();
    setState(() => _menuOpen = true);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: const Color(0xff111114),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: PerformancePanel(library: _library, heightFraction: .56),
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _controlsVisible = false;
        _menuOpen = false;
      });
    }
  }

  Future<void> _saveMoment() async {
    final c = widget.controller;
    final timeline = c.timeline;
    final track = c.snapshot.track;
    if (timeline == null || track == null) return;
    final position = track.positionAt(DateTime.now());
    final score = SongScore.prepare(
      timeline,
      identity: '${track.title}/${track.artist}',
      semantic: c.semanticProfile,
      vocalLayout: _library.settings.vocalLayout,
    );
    final index = score.timeline.indexAt(position);
    if (index < 0 ||
        !score.scenes[index].hasLyrics ||
        position >= score.scenes[index].line.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save a moment while lyrics are on screen.'),
        ),
      );
      return;
    }
    final scene = score.scenes[index];
    final line = scene.line;
    final savedLine = LyricLine(
      text: line.text,
      start: line.start,
      end: line.end,
      words: line.words,
      confidence: line.confidence,
      provenance: line.provenance,
      vocalRole: scene.vocalRole,
    );
    await _action(
      () => _library.saveMoment(
        LyricMoment(
          identity: '${track.title}/${track.artist}',
          title: track.title,
          artist: track.artist,
          line: savedLine,
          mood: scene.mood,
          section: scene.section,
          fontSeed: scene.fontSeed!,
          typographyMood: scene.typographyMood,
          object: score.objects[index],
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _library.storageFailed
                ? 'Moment could not be saved on this phone.'
                : 'Moment saved',
          ),
          action: SnackBarAction(label: 'View', onPressed: _performance),
        ),
      );
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This action could not finish. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _audioConsent() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('React to the music'),
        content: const Text(
          'Android may ask for audio permission to measure bass, mids and treble locally. No audio is saved or uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (accepted == true) await _action(widget.controller.enableAudioReaction);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final snapshot = c.snapshot;
      final track = snapshot.track;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Semantics(
          button: track?.state != PlaybackStatus.paused,
          explicitChildNodes: true,
          label: track?.state == PlaybackStatus.paused
              ? 'Paused player'
              : _controlsVisible
              ? 'Hide controls'
              : 'Show controls',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: track?.state == PlaybackStatus.paused ? null : _showControls,
            onLongPress: track != null && c.timeline != null
                ? _saveMoment
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: _controlsVisible || _menuOpen ? .12 : 1.0,
                    ),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (_, opacity, _) => MusicSurface(
                      controller: c,
                      settings: _library.settings,
                      visualizerOpacity: opacity,
                    ),
                  ),
                ),
                if (track != null &&
                    c.timeline?.quality == LyricsTimingQuality.unsynced)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 72,
                    left: 24,
                    right: 24,
                    height: MediaQuery.sizeOf(context).height * .48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lyrics · not time-synced',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            key: ValueKey(track.title + track.artist),
                            child: Text(
                              c.timeline!.lines
                                  .map((line) => line.text)
                                  .join('\n\n'),
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 25,
                                height: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (track == null)
                  Center(
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(
                            snapshot.access == NowPlayingAccess.granted
                                ? 16
                                : 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.graphic_eq,
                                color: Color(0xffef6262),
                                size: 36,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                switch (snapshot.access) {
                                  NowPlayingAccess.checking =>
                                    'Welcome to Kinetic Lyrics',
                                  NowPlayingAccess.denied =>
                                    'Feel the song through its words',
                                  NowPlayingAccess.unsupported =>
                                    'Music detection needs Android',
                                  NowPlayingAccess.error =>
                                    'Music detection is unavailable',
                                  NowPlayingAccess.granted =>
                                    'Ready when the music starts',
                                },
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              Text(switch (snapshot.access) {
                                NowPlayingAccess.checking =>
                                  'Checking access to your music player…',
                                NowPlayingAccess.denied =>
                                  'Allow notification access to detect your music player and playback position. Notification text is not read or saved.',
                                NowPlayingAccess.unsupported =>
                                  'Open this app on an Android phone to follow music from your player.',
                                NowPlayingAccess.error =>
                                  'Check notification access, then try again.',
                                NowPlayingAccess.granted =>
                                  'Play a song in your music app, then return here. Tap anywhere during playback to reveal controls.',
                              }, textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: _performance,
                                icon: const Icon(Icons.tune),
                                label: const Text('Style and saved moments'),
                              ),
                              if (snapshot.access == NowPlayingAccess.denied ||
                                  snapshot.access == NowPlayingAccess.error)
                                FilledButton(
                                  onPressed: () =>
                                      _action(c.openAccessSettings),
                                  child: const Text('Open Notification Access'),
                                ),
                              if (snapshot.access !=
                                  NowPlayingAccess.unsupported)
                                TextButton(
                                  onPressed: () => _action(c.refresh),
                                  child: const Text('Check again'),
                                ),
                              if (snapshot.access ==
                                  NowPlayingAccess.granted) ...[
                                const SizedBox(height: 32),
                                PausedAdSlot(ads: _ads, idle: true),
                                if (_ads.privacyRequired)
                                  TextButton(
                                    onPressed: _ads.privacyOptions,
                                    child: const Text('Ad privacy'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (track != null &&
                    _controlsVisible &&
                    track.state != PlaybackStatus.paused)
                  Positioned(
                    top: MediaQuery.sizeOf(context).height * .5,
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: SafeArea(
                      top: false,
                      child: Material(
                        color: const Color(0xff111114),
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(
                              child: PageView(
                                controller: _pages,
                                onPageChanged: (page) =>
                                    setState(() => _page = page),
                                children: [
                                  PlaybackPanel(
                                    controller: c,
                                    onSettings: _settings,
                                    onClose: _closeControls,
                                    onSave: _saveMoment,
                                    onAudio: _audioConsent,
                                  ),
                                  PerformancePanel(
                                    library: _library,
                                    heightFraction: .5,
                                    onClose: _closeControls,
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => _pages.animateToPage(
                                    0,
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  ),
                                  child: Text(
                                    'Playback',
                                    style: TextStyle(
                                      color: _page == 0
                                          ? Colors.white
                                          : Colors.white38,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _settings,
                                  child: Text(
                                    'Settings',
                                    style: TextStyle(
                                      color: _page == 1
                                          ? Colors.white
                                          : Colors.white38,
                                    ),
                                  ),
                                ),
                                if (_ads.privacyRequired)
                                  TextButton(
                                    onPressed: _ads.privacyOptions,
                                    child: const Text('Ad privacy'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (track?.isAdvancing == true &&
                    !c.audioSignal &&
                    !_controlsVisible &&
                    !_menuOpen)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _audioConsent,
                          icon: const Icon(Icons.graphic_eq),
                          label: Text(
                            c.audioAvailable
                                ? 'No audio signal · reconnect visualizer'
                                : 'Enable audio reaction',
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  key: const ValueKey('pause-layer'),
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .018),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: track?.state == PlaybackStatus.paused
                        ? PauseStage(
                            key: const ValueKey('full-screen-pause'),
                            controller: c,
                            library: _library,
                            ads: _ads,
                            onSave: _saveMoment,
                            onAudio: _audioConsent,
                            onSettingsChanged: (open) => _pausedSettings = open,
                          )
                        : const IgnorePointer(child: SizedBox.shrink()),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: SafeArea(
                      bottom: false,
                      child: _CornerHud(title: track?.title ?? ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CornerHud extends StatelessWidget {
  const _CornerHud({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .42),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: _MinuteClock(),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              title,
              key: const Key('corner-song-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xffb4b4bc),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Only this small text subtree updates at the minute boundary. The scene and
/// controls do not rebuild on clock ticks or receive a second-by-second timer.
class _MinuteClock extends StatefulWidget {
  const _MinuteClock();
  @override
  State<_MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<_MinuteClock>
    with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _minute;
  String get _time =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  void _schedule() {
    _minute?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _minute = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _minute = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _schedule();
    } else {
      _minute?.cancel();
    }
  }

  @override
  void dispose() {
    _minute?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Time $_time',
    excludeSemantics: true,
    child: Text(
      _time,
      key: const Key('corner-local-time'),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xffd6d6dc),
        fontFeatures: [FontFeature.tabularFigures()],
        height: 1.15,
      ),
    ),
  );
}
