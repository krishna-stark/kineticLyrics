import 'dart:async';
import 'package:flutter/material.dart';
import '../audio/beat_haptics.dart';
import '../app/performance_library.dart';
import '../visuals/performance_settings.dart';
import 'moment_screen.dart';

class PerformancePanel extends StatelessWidget {
  const PerformancePanel({
    super.key,
    required this.library,
    this.heightFraction = .82,
  });
  final PerformanceLibrary library;
  final double heightFraction;

  void _change(BuildContext context, PerformanceSettings settings) {
    unawaited(
      library.update(settings).catchError((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Applied for this session. Settings could not be saved.',
              ),
            ),
          );
        }
      }),
    );
  }

  Future<void> _testHaptics(BuildContext context) async {
    final available = await BeatHaptics.pulse();
    if (!available && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vibration is unavailable on this device.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * heightFraction,
    child: DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your performance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Style'),
                Tab(text: 'Moments'),
              ],
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: library,
                builder: (context, _) {
                  final settings = library.settings;
                  return TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const Text(
                            'How the music moves',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Keep the song’s identity. Choose the strength of its movement.',
                            style: TextStyle(
                              color: Colors.white60,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (final intensity in PerformanceIntensity.values)
                            ListTile(
                              selected: settings.intensity == intensity,
                              leading: Icon(
                                settings.intensity == intensity
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: Colors.white,
                              ),
                              onTap: () => _change(
                                context,
                                settings.copyWith(intensity: intensity),
                              ),
                              contentPadding: EdgeInsets.zero,
                              title: Text(switch (intensity) {
                                PerformanceIntensity.subtle => 'Subtle',
                                PerformanceIntensity.cinematic => 'Cinematic',
                                PerformanceIntensity.concert => 'Concert',
                              }),
                              subtitle: Text(switch (intensity) {
                                PerformanceIntensity.subtle =>
                                  'Gentle entrances and quiet holds',
                                PerformanceIntensity.cinematic =>
                                  'Expressive type with measured depth',
                                PerformanceIntensity.concert =>
                                  'Stronger arrivals and musical accents',
                              }),
                            ),
                          const Divider(height: 36, color: Colors.white12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reduced motion'),
                            subtitle: const Text(
                              'Stable lyrics; keep the measured spectrum.',
                            ),
                            value: settings.reduceMotion,
                            onChanged: (v) => _change(
                              context,
                              settings.copyWith(reduceMotion: v),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Beat haptics'),
                            subtitle: const Text(
                              'Measured bass accents. Requires audio reaction; Android vibration settings apply.',
                            ),
                            value: settings.haptics,
                            onChanged: (v) {
                              _change(context, settings.copyWith(haptics: v));
                              if (v) unawaited(_testHaptics(context));
                            },
                          ),
                          if (settings.haptics)
                            TextButton.icon(
                              onPressed: () => _testHaptics(context),
                              icon: const Icon(Icons.vibration),
                              label: const Text('Test vibration'),
                            ),
                          const Divider(height: 36, color: Colors.white12),
                          const Text(
                            'Vocal choreography',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected:
                                settings.vocalLayout == VocalLayout.automatic,
                            leading: Icon(
                              settings.vocalLayout == VocalLayout.automatic
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: Colors.white,
                            ),
                            onTap: () => _change(
                              context,
                              settings.copyWith(
                                vocalLayout: VocalLayout.automatic,
                              ),
                            ),
                            title: const Text('Follow available vocal cues'),
                            subtitle: const Text(
                              'Lead, response and backing when annotated.',
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected:
                                settings.vocalLayout ==
                                VocalLayout.callAndResponse,
                            leading: Icon(
                              settings.vocalLayout ==
                                      VocalLayout.callAndResponse
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: Colors.white,
                            ),
                            onTap: () => _change(
                              context,
                              settings.copyWith(
                                vocalLayout: VocalLayout.callAndResponse,
                              ),
                            ),
                            title: const Text('Call and response'),
                            subtitle: const Text(
                              'Alternate phrase positions and font voices.',
                            ),
                          ),
                        ],
                      ),
                      library.moments.isEmpty
                          ? const Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bookmark_border,
                                        size: 30,
                                        color: Colors.white60,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Keep a moment that stays with you',
                                        style: TextStyle(fontSize: 18),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Long-press the lyric screen, or tap Save moment in the controls. Replay it here and share a visual card.',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: library.moments.length,
                              separatorBuilder: (_, _) => const Divider(
                                indent: 24,
                                endIndent: 24,
                                color: Colors.white12,
                              ),
                              itemBuilder: (context, index) {
                                final moment = library.moments[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    12,
                                    8,
                                  ),
                                  title: Text(
                                    moment.line.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.4,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${moment.title} · ${moment.artist}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MomentScreen(
                                        moment: moment,
                                        settings: library.settings,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Remove saved moment',
                                    icon: const Icon(
                                      Icons.bookmark_remove_outlined,
                                    ),
                                    onPressed: () => unawaited(
                                      library.remove(moment).catchError((_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'The change could not be saved.',
                                              ),
                                            ),
                                          );
                                        }
                                      }),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
