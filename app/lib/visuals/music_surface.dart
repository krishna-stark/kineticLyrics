import '../audio/beat_haptics.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../app/kinetic_lyrics_controller.dart';
import '../audio/audio_features.dart';
import '../lyrics/domain/lyric_timeline.dart';
import 'lyric_scene.dart';
import 'beat_envelope.dart';
import 'lyric_composition.dart';
import 'spectrum_bars.dart';
import 'context_asset_store.dart';
import '../semantics/song_semantic_profile.dart';
import '../semantics/online_song_context.dart';
import '../lyrics/domain/track_identity.dart';
import 'song_score.dart';
import 'performance_settings.dart';
import 'lyric_performance.dart';
import 'instrumental_field.dart';

/// Only this isolated render surface repaints per frame. Controls do not tick.
class MusicSurface extends StatefulWidget {
  const MusicSurface({
    super.key,
    required this.controller,
    this.settings = const PerformanceSettings(),
    this.visualizerOpacity = 1,
  });
  final KineticLyricsController controller;
  final PerformanceSettings settings;
  final double visualizerOpacity;
  @override
  State<MusicSurface> createState() => _MusicSurfaceState();
}

class _MusicSurfaceState extends State<MusicSurface>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _field = SpectrumBars();
  final _haptics = HapticAccentGate();
  InstrumentalStyle _instrumentalStyle = InstrumentalStyle.spectrum;
  double _instrumentalMix = 0;
  SongScore? _score;
  VocalLayout? _scoredLayout;
  final _onlineStore = OnlineSongContextStore();
  OnlineSongContext? _online;
  ui.Image? _portrait;
  double _portraitFade = 0;
  int _contextGeneration = 0;
  final _clock = ValueNotifier<int>(0);
  final Map<int, LyricComposition> _shapes = {};
  List<LyricScene> _scenes = [];
  LyricTimeline? _timeline;
  LyricTimeline? _sceneTimeline;
  SongSemanticProfile? _semantics;
  Map<int, String?> _objects = {};
  double _takeover = 0;
  double _absence = 0;
  String? _currentObject;
  String? _previousObject;
  double _objectMix = 1;
  Size? _size;
  TextDirection? _direction;
  double _ambientTime = 0;
  Duration? _lastTick;
  String? _trackKey;
  double _trackFade = 1;
  bool _reduced = false;
  int _layoutGeneration = 0;
  bool _needsPreparation = true;
  int _preparedWindowIndex = -1;
  Size? _preparedBounds;
  double _pixelRatio = 1;
  bool _rasterizing = false;
  bool _foreground = true;

  void _warmGlyphs() {
    if (!mounted || _rasterizing) return;
    final word = _shapes.values
        .expand((composition) => composition.shots)
        .expand((shot) => shot.words)
        .where((word) => !word.rasterAttempted)
        .firstOrNull;
    if (word == null) return;
    _rasterizing = true;
    word.rasterize(_pixelRatio).whenComplete(() {
      _rasterizing = false;
      if (!mounted) return;
      _clock.value++;
      SchedulerBinding.instance.scheduleFrameCallback((_) => _warmGlyphs());
    });
  }

  final _profileFrames = <ui.FrameTiming>[];
  DateTime _profileStart = DateTime.now();

  void _recordTimings(List<ui.FrameTiming> frames) {
    if (!kProfileMode ||
        widget.controller.snapshot.track?.isAdvancing != true) {
      return;
    }
    _profileFrames.addAll(frames);
    if (DateTime.now().difference(_profileStart).inSeconds < 5 ||
        _profileFrames.length < 60) {
      return;
    }
    final build =
        _profileFrames
            .map((f) => f.buildDuration.inMicroseconds / 1000)
            .toList()
          ..sort();
    final raster =
        _profileFrames
            .map((f) => f.rasterDuration.inMicroseconds / 1000)
            .toList()
          ..sort();
    final p95 = (build.length * .95).floor().clamp(0, build.length - 1);
    debugPrint(
      'KineticFrameTiming frames=${build.length} buildP95=${build[p95].toStringAsFixed(2)}ms rasterP95=${raster[p95].toStringAsFixed(2)}ms buildMax=${build.last.toStringAsFixed(2)}ms rasterMax=${raster.last.toStringAsFixed(2)}ms',
    );
    _profileFrames.clear();
    _profileStart = DateTime.now();
  }

  AudioFeatures _heldAudio = AudioFeatures.silent;
  final _lowBeat = BeatEnvelope(decaySeconds: .18, refractorySeconds: .1);
  final _midBeat = BeatEnvelope(decaySeconds: .12, refractorySeconds: .06);
  final _highBeat = BeatEnvelope(decaySeconds: .065, refractorySeconds: .03);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kProfileMode) {
      SchedulerBinding.instance.addTimingsCallback(_recordTimings);
    }
    _ticker = createTicker((elapsed) {
      final delta = _lastTick == null
          ? 0.0
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      if (widget.controller.snapshot.track?.isAdvancing == true) {
        _ambientTime += delta;
        _portraitFade = math.min(1, _portraitFade + delta / .6);
        final features = widget.controller.audioFeatures;
        final profile = widget.controller.musicState.profile;
        _instrumentalStyle = InstrumentalField.choose(profile, features);
        final blendTarget =
            _instrumentalStyle == InstrumentalStyle.spectrum || _reduced
            ? 0.0
            : _takeover;
        _instrumentalMix +=
            (blendTarget - _instrumentalMix) * (1 - math.exp(-delta / .45));
        final position =
            widget.controller.learningPreviewPosition ??
            widget.controller.snapshot.track!.positionAt(DateTime.now());
        if (widget.settings.haptics &&
            _foreground &&
            features.live &&
            _haptics.accept(
              timestamp: features.timestamp,
              playback: position,
              attack: features.bassOnset,
              energy: features.energy,
            )) {
          unawaited(BeatHaptics.pulse());
        }
        final activeScene = math.max(0, _sceneTimeline?.indexAt(position) ?? 0);
        if (_preparedBounds != null &&
            _direction != null &&
            activeScene != _preparedWindowIndex) {
          _prepareRemaining(_preparedBounds!, _direction!);
        }
        bool wordsAt(Duration point) {
          final index = _sceneTimeline?.indexAt(point) ?? -1;
          return index >= 0 &&
              index < _scenes.length &&
              _scenes[index].hasLyrics &&
              point >= _scenes[index].line.start &&
              point < _scenes[index].line.end;
        }

        final imminent =
            wordsAt(position) ||
            wordsAt(position + const Duration(milliseconds: 700));
        _absence = imminent ? 0 : _absence + delta;
        final reading =
            widget.controller.timeline?.quality == LyricsTimingQuality.unsynced;
        final target = !reading && _absence > .35 ? 1.0 : 0.0;
        _takeover +=
            (target - _takeover) *
            (1 - math.exp(-delta / (target == 0 ? .16 : .60)));
        final original = _sceneTimeline?.indexAt(position) ?? -1;
        final valid =
            original >= 0 &&
            original < (_sceneTimeline?.lines.length ?? 0) &&
            position < _sceneTimeline!.lines[original].end;
        final object = valid ? _objects[original] : null;
        if (object != _currentObject) {
          _previousObject = _currentObject;
          _currentObject = object;
          _objectMix = 0;
        }
        _objectMix = math.min(1, _objectMix + delta / .32);
        _lowBeat.update(features.copyWith(onset: features.bassOnset), delta);
        _midBeat.update(features.copyWith(onset: features.midOnset), delta);
        _highBeat.update(features.copyWith(onset: features.trebleOnset), delta);
      }
      _trackFade = math.min(1, _trackFade + delta / .24);
      _clock.value++;
      if (widget.controller.snapshot.track?.isAdvancing != true &&
          _trackFade >= 1) {
        _ticker.stop();
        _lastTick = null;
      }
    })..start();
  }

  LineSemanticProfile? _semanticFor(LyricScene scene) =>
      _semantics?.lineAt(_timeline?.indexAt(scene.line.start) ?? scene.index);

  void _prepareScore() {
    final timeline = _timeline;
    if (timeline == null) {
      _score = null;
      _sceneTimeline = null;
      _scenes = [];
      _objects = {};
      return;
    }
    final track = widget.controller.snapshot.track;
    _score = SongScore.prepare(
      timeline,
      identity: '${track?.title}/${track?.artist}',
      semantic: _semantics,
      songObjects: _online?.objects ?? const [],
      vocalLayout: widget.settings.vocalLayout,
    );
    _sceneTimeline = _score!.timeline;
    _scenes = _score!.scenes;
    _objects = _score!.objects;
    _scoredLayout = widget.settings.vocalLayout;
  }

  void _prepareRemaining(Size bounds, TextDirection direction) {
    _needsPreparation = false;
    _preparedBounds = bounds;
    final generation = _layoutGeneration;
    final position =
        widget.controller.learningPreviewPosition ??
        widget.controller.snapshot.track?.positionAt(DateTime.now()) ??
        Duration.zero;
    final active = math.max(0, _sceneTimeline?.indexAt(position) ?? 0);
    _preparedWindowIndex = active;
    var index = math.max(0, active - 1);
    final end = math.min(_scenes.length, active + 4);
    final expired = _shapes.keys
        .where((key) => key < active - 2 || key > active + 4)
        .toList();
    for (final key in expired) {
      _shapes.remove(key)?.dispose();
    }
    void batch(Duration _) {
      if (!mounted ||
          generation != _layoutGeneration ||
          active != _preparedWindowIndex) {
        return;
      }
      final budget = Stopwatch()..start();
      while (index < end) {
        final scene = _scenes[index++];
        _shapes.putIfAbsent(
          scene.index,
          () => LyricComposition.prepare(
            scene,
            bounds,
            direction,
            semantic: _semanticFor(scene),
          ),
        );
        if (budget.elapsedMicroseconds >= 1000) {
          break;
        }
      }
      if (index < end) {
        SchedulerBinding.instance.scheduleFrameCallback(batch);
      }
      _warmGlyphs();
    }

    SchedulerBinding.instance.scheduleFrameCallback(batch);
  }

  void _clearShapes() {
    _layoutGeneration++;
    _needsPreparation = true;
    _preparedWindowIndex = -1;
    for (final shape in _shapes.values) {
      shape.dispose();
    }
    _shapes.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kProfileMode) {
      SchedulerBinding.instance.removeTimingsCallback(_recordTimings);
    }
    _ticker.dispose();
    _clock.dispose();
    _onlineStore.dispose();
    _portrait?.dispose();
    _clearShapes();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _lastTick = null;
    if (!_foreground) {
      _ticker.stop();
      _haptics.reset();
    } else if (widget.controller.snapshot.track?.isAdvancing == true &&
        !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackIsAdvancing =
        widget.controller.snapshot.track?.isAdvancing == true;
    _pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1, 3);
    _reduced =
        MediaQuery.disableAnimationsOf(context) || widget.settings.reduceMotion;
    if (!_ticker.isActive && trackIsAdvancing && _foreground) {
      _lastTick = null;
      _ticker.start();
    }
    final sourceTimeline = widget.controller.timeline;
    // Plain text has no musical timing. Never animate guessed timestamps.
    final timeline = sourceTimeline?.quality == LyricsTimingQuality.unsynced
        ? null
        : sourceTimeline;
    if (!identical(timeline, _timeline) ||
        _scoredLayout != widget.settings.vocalLayout) {
      _timeline = timeline;
      _semantics = widget.controller.semanticProfile;
      _prepareScore();
      _clearShapes();
    }
    final track = widget.controller.snapshot.track;
    final key = track == null
        ? null
        : '${track.sourcePackage}/${track.title}/${track.artist}';
    if (key != _trackKey) {
      final generation = ++_contextGeneration;
      _trackKey = key;
      _online = null;
      _portrait?.dispose();
      _portrait = null;
      _portraitFade = 0;
      _prepareScore();
      if (track != null) {
        // Start independently: lyrics and FFT rendering never await this work.
        _onlineStore.forTrack(TrackIdentity.fromNowPlaying(track)).then((
          context,
        ) async {
          if (!mounted || generation != _contextGeneration) return;
          _online = context;
          _prepareScore();
          final bytes = context.artistImage;
          if (bytes != null) {
            try {
              // Decode once before publishing to paint. Reject opaque artwork;
              // only a true transparent silhouette can preserve black backing.
              final codec = await ui.instantiateImageCodec(
                bytes,
                targetWidth: 320,
              );
              final frame = await codec.getNextFrame();
              codec.dispose();
              final raw = await frame.image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final data = raw?.buffer.asUint8List();
              final w = frame.image.width, h = frame.image.height;
              final transparent =
                  data != null &&
                  [
                    0,
                    w - 1,
                    (h - 1) * w,
                    h * w - 1,
                  ].every((p) => data[p * 4 + 3] < 20);
              if (!mounted ||
                  generation != _contextGeneration ||
                  !transparent) {
                frame.image.dispose();
                return;
              }
              _portrait = frame.image;
              _portraitFade = track.isAdvancing ? 0 : 1;
            } catch (_) {
              /* Optional artwork never breaks playback. */
            }
          }
          if (!mounted || generation != _contextGeneration) return;
          // Ticker blends against the current timestamp, never a stale line.
          _clock.value++;
        });
      }
      _ambientTime = 0;
      _field.reset();
      _heldAudio = AudioFeatures.silent;
      _haptics.reset();
      _instrumentalMix = 0;
      _lowBeat.reset();
      _midBeat.reset();
      _highBeat.reset();
      _trackFade = _reduced ? 1 : 0;
      _takeover = 0;
      _absence = 0;
      _currentObject = _previousObject = null;
      _objectMix = 1;
    }
    if (!identical(_semantics, widget.controller.semanticProfile)) {
      _semantics = widget.controller.semanticProfile;
      final position = track?.positionAt(DateTime.now()) ?? Duration.zero;
      final active = _sceneTimeline?.indexAt(position) ?? -1;
      // Preserve the active glyph geometry; new contextual artwork blends
      // immediately against the current lyric timestamp.
      final held = _shapes.remove(active);
      _clearShapes();
      if (held != null) _shapes[active] = held;
      _prepareScore();
    }
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final direction = Directionality.of(context);
            if (_size != size || _direction != direction) {
              _size = size;
              _direction = direction;
              _clearShapes();
            }
            // Reserve padding for every possible transform, plus a 24px hard edge.
            final safe = Size(
              math.max(1, math.min(size.width * .82, size.width - 64)),
              math.max(
                1,
                math.min(size.height * .43, size.height * 2 / 3 - 128),
              ),
            );
            final position =
                widget.controller.learningPreviewPosition ??
                track?.positionAt(DateTime.now()) ??
                Duration.zero;
            final active = _sceneTimeline?.indexAt(position) ?? -1;
            if (active >= 0 && active < _scenes.length) {
              final scene = _scenes[active];
              _shapes.putIfAbsent(
                active,
                () => LyricComposition.prepare(
                  scene,
                  safe,
                  direction,
                  semantic: _semanticFor(scene),
                ),
              );
            }
            if (_needsPreparation) _prepareRemaining(safe, direction);
            return CustomPaint(
              size: size,
              painter: _MusicPainter(
                controller: widget.controller,
                field: _field,
                visualizerOpacity: widget.visualizerOpacity,
                settings: widget.settings,
                instrumentalStyle: () => _instrumentalStyle,
                instrumentalMix: () => _instrumentalMix,
                portrait: () => _portrait,
                portraitFade: () => _portraitFade,
                clock: _clock,
                scenes: _scenes,
                shapes: _shapes,
                reduced: _reduced,
                timeline: _sceneTimeline,
                currentObject: () => _currentObject,
                previousObject: () => _previousObject,
                objectMix: () => _objectMix,
                takeover: () => _takeover,
                ambientTime: () => _ambientTime,
                fade: () => _trackFade,
                lowHit: () => _lowBeat.strength,
                midHit: () => _midBeat.strength,
                highHit: () => _highBeat.strength,
                audio: () {
                  if (widget.controller.snapshot.track?.isAdvancing == true) {
                    _heldAudio = widget.controller.audioFeatures;
                  }
                  return _heldAudio;
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MusicPainter extends CustomPainter {
  _MusicPainter({
    required this.controller,
    required this.field,
    required this.visualizerOpacity,
    required this.settings,
    required this.instrumentalStyle,
    required this.instrumentalMix,
    required this.portrait,
    required this.portraitFade,
    required ValueNotifier<int> clock,
    required this.scenes,
    required this.shapes,
    required this.reduced,
    required this.timeline,
    required this.currentObject,
    required this.previousObject,
    required this.objectMix,
    required this.takeover,
    required this.ambientTime,
    required this.fade,
    required this.audio,
    required this.lowHit,
    required this.midHit,
    required this.highHit,
  }) : super(repaint: clock);
  final KineticLyricsController controller;
  final SpectrumBars field;
  final double visualizerOpacity;
  final PerformanceSettings settings;
  final InstrumentalStyle Function() instrumentalStyle;
  final double Function() instrumentalMix;
  final ui.Image? Function() portrait;
  final double Function() portraitFade;
  final List<LyricScene> scenes;
  final Map<int, LyricComposition> shapes;
  final bool reduced;
  final LyricTimeline? timeline;
  final String? Function() currentObject;
  final String? Function() previousObject;
  final double Function() objectMix;
  final double Function() takeover;
  final double Function() ambientTime;
  final double Function() fade;
  final AudioFeatures Function() audio;
  final double Function() lowHit;
  final double Function() midHit;
  final double Function() highHit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.src);
    final track = controller.snapshot.track;
    final position =
        controller.learningPreviewPosition ??
        track?.positionAt(DateTime.now()) ??
        Duration.zero;
    final index = timeline?.indexAt(position) ?? -1;
    final scene =
        index >= 0 &&
            index < scenes.length &&
            scenes[index].hasLyrics &&
            position < scenes[index].line.end
        ? scenes[index]
        : null;
    final features = audio();
    final time = ambientTime();
    final alpha = reduced ? 1.0 : fade();
    if (alpha < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    } else {
      canvas.save();
    }
    _background(canvas, size, features, time, scene);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 2 / 3));
    // Normal phrase handoffs retain a bounded outgoing shot, including gaps.
    // Voice overlaps retain their existing side-by-side choreography below.
    final outgoingIndex = scene != null ? scene.index - 1 : index;
    if (!reduced && outgoingIndex >= 0 && outgoingIndex < scenes.length) {
      final outgoing = scenes[outgoingIndex];
      final shape = shapes[outgoingIndex];
      if (shape != null &&
          outgoing.hasLyrics &&
          position >= outgoing.line.end &&
          (scene == null || outgoing.vocalRole == scene.vocalRole)) {
        LyricPerformance.paint(
          canvas,
          size,
          outgoing,
          shape,
          position,
          settings: settings,
          handoff: scene != null,
          outgoingLimit: 1,
        );
      }
    }
    final nextIndex = index + 1;
    if (!reduced && nextIndex >= 0 && nextIndex < scenes.length) {
      final next = scenes[nextIndex];
      final shape = shapes[nextIndex];
      if (shape != null &&
          next.hasLyrics &&
          position < next.line.start &&
          next.line.start - position <= const Duration(milliseconds: 160)) {
        LyricPerformance.paint(
          canvas,
          size,
          next,
          shape,
          position,
          settings: settings,
        );
      }
    }
    if (scene != null) {
      final previous = scene.index > 0 ? scenes[scene.index - 1] : null;
      final simultaneous =
          previous != null &&
          previous.hasLyrics &&
          previous.vocalRole != scene.vocalRole &&
          position < previous.line.end;
      if (previous != null &&
          previous.hasLyrics &&
          previous.vocalRole != scene.vocalRole &&
          (simultaneous ||
              position - scene.line.start <
                  const Duration(milliseconds: 1200))) {
        final previousShape = shapes[previous.index];
        if (previousShape != null) {
          LyricPerformance.paint(
            canvas,
            size,
            previous,
            previousShape,
            simultaneous
                ? position
                : previous.line.end - const Duration(milliseconds: 220),
            settings: settings,
            reduced: reduced,
            echo: !simultaneous,
            simultaneous: simultaneous,
            opacity: simultaneous
                ? .84
                : .22 *
                      (1 - (position - scene.line.start).inMilliseconds / 1200),
          );
        }
      }
      final shape = shapes[scene.index];
      if (shape != null) {
        LyricPerformance.paint(
          canvas,
          size,
          scene,
          shape,
          position,
          settings: settings,
          reduced: reduced,
          bassHit: lowHit(),
          midHit: midHit(),
          simultaneous: simultaneous,
          outgoingLimit: scene.index > 0 ? 1 : 2,
          handoff:
              scene.index + 1 < scenes.length &&
              scenes[scene.index + 1].line.start - scene.line.end <=
                  const Duration(milliseconds: 120),
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  void _background(
    Canvas canvas,
    Size size,
    AudioFeatures audio,
    double t,
    LyricScene? scene,
  ) {
    final mix = reduced ? 1.0 : objectMix();
    final image = portrait();
    if (image != null) {
      final height = math.min(size.height * .48, size.width * .84);
      final width = height * image.width / image.height;
      final center = Offset(size.width * .72, size.height * .34);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 2 / 3));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: center, width: width, height: height),
        Paint()
          ..filterQuality = FilterQuality.low
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(
              alpha: .26 * (reduced ? 1 : portraitFade()),
            ),
            BlendMode.srcIn,
          ),
      );
      canvas.restore();
    }
    void object(String? id, double opacity) {
      if (id == null || opacity <= .001) return;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 2 / 3));
      final center = Offset(size.width * .72, size.height * .23);
      final base = size.width * .22;
      ContextAssetStore.paint(
        canvas,
        id,
        center,
        base + audio.bass * 3,
        opacity * (.20 + audio.mid * .025),
      );
      canvas.restore();
    }

    object(previousObject(), 1 - mix);
    object(currentObject(), mix);
    field.paint(
      canvas,
      size,
      audio,
      t,
      takeover: reduced ? (scene == null ? 1 : 0) : takeover(),
      reduced: reduced,
      opacity: (1 - instrumentalMix() * .78) * visualizerOpacity,
    );
    if (!reduced) {
      InstrumentalField.paint(
        canvas,
        size,
        audio,
        reveal: instrumentalMix() * visualizerOpacity,
        style: instrumentalStyle(),
        settings: settings,
      );
    }
  }

  @override
  bool shouldRepaint(_MusicPainter oldDelegate) => true;
}
