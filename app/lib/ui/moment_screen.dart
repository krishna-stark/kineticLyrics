import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/performance_library.dart';
import '../lyrics/domain/lyric_timeline.dart';
import '../visuals/context_asset_store.dart';
import '../visuals/lyric_composition.dart';
import '../visuals/lyric_performance.dart';
import '../visuals/lyric_scene.dart';
import '../visuals/performance_settings.dart';

class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key, required this.moment, required this.settings});
  final LyricMoment moment;
  final PerformanceSettings settings;
  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  LyricComposition? _composition;
  Size? _size;
  bool _sharing = false;
  bool _ready = false;
  int _generation = 0;
  late final LyricScene _scene;

  @override
  void initState() {
    super.initState();
    final moment = widget.moment;
    final enriched = LyricTimeline(
      provider: 'saved',
      quality: LyricsTimingQuality.lineSynced,
      lines: [moment.line],
    ).enrich().lines.first;
    _scene = LyricScene(
      enriched,
      0,
      moment.mood,
      0,
      refrain: moment.section == SongSection.refrain,
      section: moment.section,
      fontSeed: moment.fontSeed,
      typographyMood: moment.typographyMood,
      vocalRole: enriched.vocalRole,
      directed: true,
    );
    _clock = AnimationController(
      vsync: this,
      duration: enriched.end - enriched.start,
    );
  }

  Future<void> _warm(
    LyricComposition shape,
    int generation,
    double ratio,
  ) async {
    for (final word in shape.shots.expand((s) => s.words)) {
      if (!mounted || generation != _generation) return;
      await word.rasterize(ratio);
    }
    if (!mounted || generation != _generation) return;
    setState(() => _ready = true);
    if (!MediaQuery.disableAnimationsOf(context) &&
        !widget.settings.reduceMotion) {
      _clock.repeat();
    }
  }

  Future<void> _share() async {
    if (_sharing || _composition == null || !_ready) return;
    setState(() => _sharing = true);
    try {
      const size = Size(1080, 1920);
      final composition = LyricComposition.prepare(
        _scene,
        const Size(860, 780),
        TextDirection.ltr,
      );
      try {
        final position =
            _scene.line.start +
            Duration(
              microseconds:
                  ((_scene.line.end - _scene.line.start).inMicroseconds *
                          _clock.value)
                      .round(),
            );
        final shot = composition.at(position) ?? composition.shots.first;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
        _paintObject(canvas, size, widget.moment.object);
        // Export a readable card for the selected shot, never a halfway-entered
        // word or a screenshot of controls. No audio is captured or exported.
        LyricPerformance.paint(
          canvas,
          size,
          _scene,
          composition,
          shot.start + (shot.end - shot.start) ~/ 2,
          reduced: true,
          settings: widget.settings,
        );
        _paintCaption(canvas, size, widget.moment);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        picture.dispose();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (data == null) throw StateError('Export unavailable');
        if (!mounted) return;
        await const MethodChannel(
          'kinetic_lyrics/moments',
        ).invokeMethod<void>('shareImage', {
          'png': data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          'text': '${widget.moment.title} — ${widget.moment.artist}',
        });
      } finally {
        composition.dispose();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing is unavailable. Your moment is still saved.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _clock.dispose();
    _composition?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: const Text('Saved moment'),
      actions: [
        IconButton(
          tooltip: 'Share visual card',
          onPressed: _ready && !_sharing ? _share : null,
          icon: _sharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_size != size) {
          _size = size;
          _ready = false;
          _clock.stop();
          _composition?.dispose();
          _composition = LyricComposition.prepare(
            _scene,
            Size(size.width * .78, size.height * .42),
            Directionality.of(context),
          );
          final generation = ++_generation;
          unawaited(
            _warm(
              _composition!,
              generation,
              MediaQuery.devicePixelRatioOf(context).clamp(1, 3),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _MomentPainter(
                  widget.moment,
                  _scene,
                  _composition!,
                  _clock,
                  widget.settings,
                  MediaQuery.disableAnimationsOf(context) ||
                      widget.settings.reduceMotion,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.moment.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.moment.artist,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Visual replay · no recorded audio',
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _clock,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _clock.value,
                      color: Colors.white70,
                      backgroundColor: Colors.white12,
                      minHeight: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MomentPainter extends CustomPainter {
  _MomentPainter(
    this.moment,
    this.scene,
    this.composition,
    this.clock,
    this.settings,
    this.reduced,
  ) : super(repaint: clock);
  final LyricMoment moment;
  final LyricScene scene;
  final LyricComposition composition;
  final AnimationController clock;
  final PerformanceSettings settings;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.src);
    _paintObject(canvas, size, moment.object);
    final position =
        scene.line.start +
        Duration(
          microseconds:
              ((scene.line.end - scene.line.start).inMicroseconds *
                      (reduced ? .5 : clock.value))
                  .round(),
        );
    LyricPerformance.paint(
      canvas,
      size,
      scene,
      composition,
      position,
      settings: settings,
      reduced: reduced,
    );
  }

  @override
  bool shouldRepaint(_MomentPainter old) => true;
}

void _paintObject(Canvas canvas, Size size, String? object) {
  if (object == null) return;
  ContextAssetStore.paint(
    canvas,
    object,
    Offset(size.width * .72, size.height * .23),
    size.width * .22,
    .16,
  );
}

void _paintCaption(Canvas canvas, Size size, LyricMoment moment) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    text: TextSpan(
      text: '${moment.title}\n${moment.artist}',
      style: const TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 32,
        height: 1.7,
        color: Colors.white70,
      ),
    ),
  )..layout(maxWidth: size.width - 144);
  painter.paint(
    canvas,
    Offset((size.width - painter.width) / 2, size.height - 250),
  );
  painter.dispose();
}
