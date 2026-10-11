import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';

/// Original synthetic lyrics for repeatable three-minute scene reviews.
/// These are visual test fixtures, not evidence of real-song acceptance.
class ReviewPrototype {
  const ReviewPrototype(this.name, this.timeline);
  final String name;
  final LyricTimeline timeline;
  static final all = [fast, normal, sparse];
  static final fast = ReviewPrototype(
    'Fast · multilingual',
    LyricTimeline(
      provider: 'review-fixture',
      quality: LyricsTimingQuality.lineSynced,
      lines: [
        for (var i = 0; i < 450; i++)
          LyricLine(
            text: const [
              'Keep the rhythm',
              'మనసులో ప్రేమ',
              'உன் காதல்',
              'Words stay together',
              'Chase the light',
            ][i % 5],
            start: Duration(milliseconds: i * 400),
            end: Duration(milliseconds: (i + 1) * 400),
          ),
      ],
    ),
  );
  static final normal = ReviewPrototype(
    'Verse · chorus · bridge',
    LyricTimeline(
      provider: 'review-fixture',
      quality: LyricsTimingQuality.lineSynced,
      lines: [
        for (var i = 0; i < 36; i++)
          LyricLine(
            text: i >= 24 && i < 28
                ? 'Alone beneath the quiet moon'
                : i % 12 >= 8
                ? const [
                    'Love carries us home',
                    'We dance beneath the sun',
                    'Hearts open to the light',
                    'Together we begin again',
                  ][i % 4]
                : const [
                    'Footsteps echo in the city',
                    'I hear your voice beside me',
                    'We turn the pages slowly',
                    'The morning waits for us',
                  ][i % 4],
            start: Duration(seconds: i * 5),
            end: Duration(milliseconds: i * 5000 + 4300),
          ),
      ],
    ),
  );
  static final sparse = ReviewPrototype(
    'Sparse · instrumental',
    LyricTimeline(
      provider: 'review-fixture',
      quality: LyricsTimingQuality.lineSynced,
      lines: const [
        LyricLine(
          text: 'Quiet water',
          start: Duration(seconds: 24),
          end: Duration(seconds: 30),
        ),
        LyricLine(
          text: 'The moon stays with me',
          start: Duration(seconds: 74),
          end: Duration(seconds: 82),
        ),
        LyricLine(
          text: 'One last breath',
          start: Duration(seconds: 145),
          end: Duration(seconds: 152),
        ),
      ],
    ),
  );
}
