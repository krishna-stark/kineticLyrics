import 'package:flutter/material.dart';
import '../ads/song_ads.dart';
import '../app/kinetic_lyrics_controller.dart';
import '../app/performance_library.dart';
import 'playback_panel.dart';
import 'performance_panel.dart';

/// A quiet full-screen pause destination. Content scrolls on compact displays
/// and at larger text sizes; the advertisement never shares a control target.
class PauseStage extends StatefulWidget {
  const PauseStage({
    super.key,
    required this.controller,
    required this.library,
    required this.ads,
    required this.onSave,
    required this.onAudio,
    required this.onSettingsChanged,
  });
  final KineticLyricsController controller;
  final PerformanceLibrary library;
  final SongAds ads;
  final VoidCallback onSave, onAudio;
  final ValueChanged<bool> onSettingsChanged;
  @override
  State<PauseStage> createState() => _PauseStageState();
}

class _PauseStageState extends State<PauseStage> {
  final _pages = PageController();
  int _page = 0;
  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeInOutCubic,
  );
  @override
  void dispose() {
    widget.onSettingsChanged(false);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.controller.snapshot.track;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (value) {
                    setState(() => _page = value);
                    widget.onSettingsChanged(value == 1);
                  },
                  children: [
                    LayoutBuilder(
                      builder: (context, bounds) => SingleChildScrollView(
                        key: const ValueKey('pause-scroll'),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: bounds.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    20,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'NOW PLAYING · PAUSED',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          letterSpacing: 2,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        track?.title ?? '',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontSize: 34,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        track?.artist ?? '',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (track?.album?.isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            track!.album!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      Container(
                                        width: 28,
                                        height: 2,
                                        color: const Color(0xffd84b52),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: PausedAdSlot(ads: widget.ads),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 24,
                                    bottom: 8,
                                  ),
                                  child: PlaybackPanel(
                                    compact: true,
                                    controller: widget.controller,
                                    onSettings: () => _go(1),
                                    onClose: () {},
                                    onSave: widget.onSave,
                                    onAudio: widget.onAudio,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    PerformancePanel(
                      library: widget.library,
                      heightFraction: 1,
                      onClose: () => _go(0),
                    ),
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _go(0),
                    child: Text(
                      'Playback',
                      style: TextStyle(
                        color: _page == 0 ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _go(1),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: _page == 1 ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                  if (widget.ads.privacyRequired)
                    TextButton(
                      onPressed: widget.ads.privacyOptions,
                      child: const Text('Ad privacy'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
