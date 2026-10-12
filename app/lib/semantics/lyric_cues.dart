/// Exact phrase cues with one shared Unicode boundary classifier. No regex
/// is compiled per anchor, line, script, or object kind.
class LyricCues {
  static final _wordCharacter = RegExp(r'^[\p{L}\p{M}\p{N}_]$', unicode: true);
  static bool contains(String text, List<String> anchors) =>
      matches(text, anchors).isNotEmpty;

  static Iterable<({int start, int end, String anchor})> matches(
    String text,
    List<String> anchors,
  ) sync* {
    for (final anchor in anchors) {
      if (anchor.isEmpty) continue;
      var index = text.indexOf(anchor);
      while (index >= 0) {
        final end = index + anchor.length;
        var left = index - 1;
        if (left > 0 &&
            _low(text.codeUnitAt(left)) &&
            _high(text.codeUnitAt(left - 1))) {
          left--;
        }
        var right = end + 1;
        if (end < text.length &&
            _high(text.codeUnitAt(end)) &&
            right < text.length &&
            _low(text.codeUnitAt(right))) {
          right++;
        }
        final before =
            index == 0 || !_wordCharacter.hasMatch(text.substring(left, index));
        final after =
            end == text.length ||
            !_wordCharacter.hasMatch(text.substring(end, right));
        if (before && after) yield (start: index, end: end, anchor: anchor);
        index = text.indexOf(anchor, index + 1);
      }
    }
  }

  static bool _low(int c) => c >= 0xdc00 && c <= 0xdfff;
  static bool _high(int c) => c >= 0xd800 && c <= 0xdbff;
}
