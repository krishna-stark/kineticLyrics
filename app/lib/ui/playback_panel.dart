import 'dart:async';
import 'package:flutter/material.dart';
import '../app/kinetic_lyrics_controller.dart';
import '../lyrics/domain/lyric_timeline.dart';

/// Repaints the song clock only while this panel is visible, never the scene.
class PlaybackPanel extends StatefulWidget {
  const PlaybackPanel({
    super.key,
    required this.controller,
    this.compact = false,
    required this.onSettings,
    required this.onSave,
    required this.onAudio,
    required this.onClose,
  });
  final KineticLyricsController controller;
  final bool compact;
  final VoidCallback onSettings, onSave, onAudio, onClose;
  @override
  State<PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<PlaybackPanel> {
  Timer? _clock;
  double? _drag;
  bool _busy = false;
  String? _identity;
  String? _seekIdentity;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && widget.controller.snapshot.track?.isAdvancing == true) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _command(String action, {Duration? position}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.controlPlayback(action, position: position);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your music player could not accept this control.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _drag = null;
        });
      }
    }
  }

  String _time(int ms) =>
      '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final track = c.snapshot.track;
    if (track == null) {
      return const Center(child: Text('Start a song in your music player'));
    }
    final identity = '${track.sourcePackage}/${track.title}/${track.artist}';
    if (_identity != identity) {
      _identity = identity;
      _drag = null;
    }
    final total = track.duration?.inMilliseconds ?? 0;
    final position =
        (_drag ?? track.positionAt(DateTime.now()).inMilliseconds.toDouble())
            .clamp(0, total > 0 ? total : 0)
            .toDouble();
    final enabled = c.transportAvailable && !_busy;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.compact)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playback',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Close controls',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          if (!widget.compact)
            Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (!widget.compact && track.artist.isNotEmpty)
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: widget.compact
                  ? const Color(0xffd84b52)
                  : Colors.white,
              thumbColor: widget.compact
                  ? const Color(0xffd84b52)
                  : Colors.white,
              inactiveTrackColor: Colors.white24,
            ),
            child: Slider(
              semanticFormatterCallback: (value) => _time(value.round()),
              value: position,
              max: total > 0 ? total.toDouble() : 1,
              onChangeStart: (_) => _seekIdentity = identity,
              onChanged: enabled && track.canSeek && total > 0
                  ? (value) => setState(() => _drag = value)
                  : null,
              onChangeEnd: enabled && track.canSeek && total > 0
                  ? (value) {
                      final current = c.snapshot.track;
                      if (_seekIdentity !=
                          '${current?.sourcePackage}/${current?.title}/${current?.artist}') {
                        setState(() => _drag = null);
                        return;
                      }
                      _command(
                        'seek',
                        position: Duration(milliseconds: value.round()),
                      );
                    }
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _time(position.round()),
                style: const TextStyle(color: Colors.white54),
              ),
              Text(
                total > 0 ? _time(total) : '—',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous song',
                color: Colors.white,
                disabledColor: Colors.white24,
                iconSize: 32,
                onPressed: enabled && track.canPrevious
                    ? () => _command('previous')
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 20),
              IconButton.filled(
                tooltip: track.isAdvancing ? 'Pause' : 'Play',
                iconSize: 36,
                style: IconButton.styleFrom(
                  backgroundColor: widget.compact
                      ? const Color(0xffcf3944)
                      : Colors.white,
                  foregroundColor: widget.compact ? Colors.white : Colors.black,
                ),
                onPressed: enabled && track.canToggle
                    ? () => _command(track.isAdvancing ? 'pause' : 'play')
                    : null,
                icon: Icon(
                  track.isAdvancing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                tooltip: 'Next song',
                color: Colors.white,
                disabledColor: Colors.white24,
                iconSize: 32,
                onPressed: enabled && track.canNext
                    ? () => _command('next')
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          if (!widget.compact)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: c.timeline == null ? null : widget.onSave,
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save moment'),
                ),
                TextButton.icon(
                  onPressed: c.audioSignal ? null : widget.onAudio,
                  icon: const Icon(Icons.graphic_eq),
                  label: Text(
                    c.audioSignal
                        ? 'Audio reaction on'
                        : c.audioAvailable
                        ? 'No audio signal · check volume'
                        : 'Enable audio reaction',
                  ),
                ),
                TextButton(
                  onPressed: () => c.retryLyrics(),
                  child: const Text('Retry lyrics'),
                ),
              ],
            ),
          if (!widget.compact)
            Text(
              switch (c.lyricsState) {
                LyricsLoadState.notFound =>
                  'Lyrics unavailable · instrumental experience',
                LyricsLoadState.loading =>
                  'Finding lyrics · music visuals continue',
                LyricsLoadState.error =>
                  'Lyrics could not load. Check your connection and retry.',
                LyricsLoadState.ready =>
                  c.timeline?.quality == LyricsTimingQuality.unsynced
                      ? 'Plain lyrics · scroll to read; synchronization unavailable'
                      : 'Tap anywhere to hide controls',
                LyricsLoadState.idle => 'Music detected',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          if (!widget.compact)
            TextButton.icon(
              onPressed: widget.onSettings,
              icon: const Icon(Icons.swipe_left_alt),
              label: const Text('Swipe for settings'),
            ),
        ],
      ),
    );
  }
}
