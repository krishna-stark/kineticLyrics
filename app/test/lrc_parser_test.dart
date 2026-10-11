import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/data/lrc_parser.dart';

void main() {
  test('parses LRC timestamps and derives line ends', () {
    final lines = LrcParser().parse(
      '[00:01.20]Hello world\n[00:04.500]Again',
      trackDuration: const Duration(seconds: 8),
    );

    expect(lines, hasLength(2));
    expect(lines.first.start, const Duration(milliseconds: 1200));
    expect(lines.first.end, const Duration(milliseconds: 4500));
    expect(lines.first.words, hasLength(2));
    expect(
      lines.first.words.last.end,
      lessThan(const Duration(milliseconds: 4100)),
      reason: 'estimated singing should leave a hold before the next line',
    );
    expect(lines.last.end, const Duration(seconds: 8));
  });

  test('keeps scripts without spaces as a single safe phrase', () {
    final lines = LrcParser().parse(
      '[00:01.00]夜に駆ける',
      trackDuration: const Duration(seconds: 4),
    );

    expect(lines.single.text, '夜に駆ける');
    expect(lines.single.words.single.text, '夜に駆ける');
  });
}
