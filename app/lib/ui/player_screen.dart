import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../app/kinetic_lyrics_controller.dart';
import '../learning/on_device_lyrics_learner.dart';
import '../now_playing/now_playing_snapshot.dart';
import '../visuals/music_surface.dart';
import '../visuals/song_score.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../app/performance_library.dart';
import 'performance_panel.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.controller});
  final KineticLyricsController controller;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final _library = PerformanceLibrary();
  bool _controlsVisible = false;
  bool _menuOpen = false;
  Timer? _hide;
  bool _foreground = true;
  bool _screenAwake = false;
  void _syncDisplay() {
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
      _hide = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

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
    final position =
        c.learningPreviewPosition ?? track.positionAt(DateTime.now());
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

  Future<void> _preflight() async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, size: 32),
                const SizedBox(height: 16),
                Text(
                  'Create a local lyric draft',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Download an approximately 160 MB multilingual model once. Android will then ask to capture playback audio.\n\nRecognition happens locally. Captured audio is never uploaded. AI drafts are saved for the next playback. Singing and background music can produce incorrect words. Timing is approximate.\n\nYou can cancel at any time and retry later.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Download and continue'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep the instrumental experience'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted == true && mounted) {
      await _action(widget.controller.startLearningLyrics);
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
      final learning = c.learningStatus;
      final busy = const {
        LearningState.preparingModel,
        LearningState.awaitingCapturePermission,
        LearningState.listening,
        LearningState.finalizing,
      }.contains(learning.state);
      return Scaffold(
        backgroundColor: Colors.black,
        body: Semantics(
          button: true,
          explicitChildNodes: true,
          label: _controlsVisible ? 'Hide controls' : 'Show controls',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showControls,
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
                if (track == null)
                  Center(
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (track != null &&
                    (_controlsVisible ||
                        busy ||
                        learning.state == LearningState.unavailable))
                  Positioned(
                    top: MediaQuery.sizeOf(context).height * .5,
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: SafeArea(
                      top: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Material(
                          color: const Color(0xf2111114),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (busy ||
                                    learning.state == LearningState.unavailable)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (learning.state ==
                                            LearningState.preparingModel) ...[
                                          LinearProgressIndicator(
                                            value: learning.progress > 0
                                                ? learning.progress
                                                : null,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Text(switch (learning.state) {
                                          LearningState.preparingModel =>
                                            'Preparing local AI · ${(learning.progress * 100).round()}%',
                                          LearningState
                                              .awaitingCapturePermission =>
                                            'Approve Android playback-audio capture to continue.',
                                          LearningState.listening =>
                                            learning.message ??
                                                'Learning an unverified AI draft for replay…',
                                          LearningState.finalizing =>
                                            'Saving lyrics on this phone…',
                                          _ =>
                                            learning.message ??
                                                'No clear lyrics were recognized. Play the song and retry.',
                                        }, textAlign: TextAlign.center),
                                        if (busy)
                                          TextButton(
                                            onPressed: () =>
                                                _action(c.cancelLearningLyrics),
                                            child: const Text('Cancel AI'),
                                          ),
                                        if (!busy)
                                          TextButton(
                                            onPressed: _preflight,
                                            child: const Text('Retry local AI'),
                                          ),
                                      ],
                                    ),
                                  ),
                                if (!busy &&
                                    learning.state !=
                                        LearningState.unavailable &&
                                    _controlsVisible)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(switch (c.lyricsState) {
                                          LyricsLoadState.loading =>
                                            'Finding lyrics · music visuals continue',
                                          LyricsLoadState.notFound =>
                                            'Lyrics unavailable · instrumental experience',
                                          LyricsLoadState.error =>
                                            'Lyrics could not load. Check your connection and retry.',
                                          LyricsLoadState.ready =>
                                            c.timeline?.provider == 'on-device'
                                                ? 'AI draft · words and timing unverified'
                                                : 'Tap anywhere to hide controls',
                                          LyricsLoadState.idle =>
                                            'Music detected',
                                        }, textAlign: TextAlign.center),
                                        if (_controlsVisible ||
                                            c.lyricsState ==
                                                LyricsLoadState.error)
                                          TextButton(
                                            onPressed: () =>
                                                _action(c.retryLyrics),
                                            child: const Text('Retry lyrics'),
                                          ),
                                        if (c.lyricsState ==
                                                LyricsLoadState.notFound &&
                                            track.isAdvancing)
                                          TextButton(
                                            onPressed: _preflight,
                                            child: const Text(
                                              'Learn lyrics on device',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                if (_controlsVisible)
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _performance,
                                        icon: const Icon(Icons.tune),
                                        label: const Text('Style and moments'),
                                      ),
                                      TextButton.icon(
                                        onPressed: c.timeline == null
                                            ? null
                                            : _saveMoment,
                                        icon: const Icon(Icons.bookmark_border),
                                        label: const Text('Save moment'),
                                      ),
                                    ],
                                  ),
                                if (_controlsVisible)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: TextButton.icon(
                                      onPressed: widget.controller.audioSignal
                                          ? null
                                          : _audioConsent,
                                      icon: Icon(
                                        widget.controller.audioAvailable
                                            ? Icons.check
                                            : Icons.graphic_eq,
                                      ),
                                      label: Text(
                                        widget.controller.audioAvailable
                                            ? widget.controller.audioSignal
                                                  ? 'Audio reaction on'
                                                  : 'No audio signal · check volume'
                                            : 'Enable audio reaction',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
