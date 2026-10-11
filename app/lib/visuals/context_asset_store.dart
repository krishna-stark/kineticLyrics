import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original, prepared CC0 vector artwork. No downloads or generation in paint.
class ContextAssetStore {
  static const license = 'CC0-1.0';
  static Set<String> get availableIds => Set.unmodifiable(_paths.keys);
  static final Map<String, Path> _paths = {
    'guitar': Path()
      ..moveTo(-.55, .9)
      ..cubicTo(-1.1, .35, -.9, -.25, -.38, -.12)
      ..quadraticBezierTo(-.12, -.05, -.03, -.37)
      ..lineTo(.46, -.9)
      ..lineTo(.65, -.74)
      ..lineTo(.18, -.2)
      ..quadraticBezierTo(.05, .13, .3, .28)
      ..cubicTo(.78, .63, .05, 1.2, -.55, .9)
      ..close()
      ..moveTo(-.47, .58)
      ..lineTo(.55, -.82)
      ..moveTo(-.6, .43)
      ..lineTo(-.25, .7),
    'raisedFist': Path()
      ..moveTo(-.35, 1)
      ..lineTo(-.38, .3)
      ..cubicTo(-.9, .08, -.92, -.26, -.65, -.36)
      ..lineTo(-.56, -.22)
      ..lineTo(-.56, -.7)
      ..quadraticBezierTo(-.49, -.96, -.27, -.8)
      ..quadraticBezierTo(-.1, -1.02, .08, -.82)
      ..quadraticBezierTo(.31, -.98, .46, -.74)
      ..quadraticBezierTo(.7, -.86, .78, -.6)
      ..lineTo(.76, -.07)
      ..quadraticBezierTo(.75, .2, .42, .36)
      ..lineTo(.4, 1)
      ..close()
      ..moveTo(-.27, -.78)
      ..lineTo(-.27, -.4)
      ..moveTo(.08, -.8)
      ..lineTo(.08, -.42)
      ..moveTo(.45, -.7)
      ..lineTo(.45, -.4)
      ..moveTo(-.62, -.25)
      ..quadraticBezierTo(-.1, -.42, .35, -.17),
    'mountain': Path()
      ..moveTo(-1, .8)
      ..lineTo(-.25, -.9)
      ..lineTo(.2, .2)
      ..lineTo(.6, -.35)
      ..lineTo(1, .8)
      ..close()
      ..moveTo(-.48, -.38)
      ..lineTo(-.25, -.2)
      ..lineTo(-.05, -.4),
    'ocean': _ocean(),
    'river': Path()
      ..moveTo(-.25, -1)
      ..cubicTo(1, -.4, -1, .1, -.8, 1)
      ..moveTo(.15, -1)
      ..cubicTo(1.4, -.4, -.6, .1, .3, 1),
    'cloud': Path()
      ..moveTo(-.65, .5)
      ..cubicTo(-1.2, .5, -1.15, -.25, -.6, -.25)
      ..cubicTo(-.7, -1, .45, -1, .55, -.35)
      ..cubicTo(1.2, -.4, 1.3, .5, .65, .5)
      ..close(),
    'bird': Path()
      ..moveTo(-1, .25)
      ..quadraticBezierTo(-.55, -.6, 0, .05)
      ..quadraticBezierTo(.55, -.6, 1, .25)
      ..moveTo(0, .05)
      ..lineTo(.08, .4),
    'butterfly': Path()
      ..moveTo(0, 0)
      ..cubicTo(-1.3, -1.6, -1.4, .4, -.25, .25)
      ..cubicTo(-1, 1.3, -.2, 1.3, 0, .2)
      ..cubicTo(.2, 1.3, 1, 1.3, .25, .25)
      ..cubicTo(1.4, .4, 1.3, -1.6, 0, 0)
      ..moveTo(-.1, -.05)
      ..lineTo(-.3, -.55)
      ..moveTo(.1, -.05)
      ..lineTo(.3, -.55),
    'tree': Path()
      ..moveTo(0, 1)
      ..lineTo(0, .2)
      ..moveTo(-.25, .2)
      ..cubicTo(-1.2, .5, -1.1, -.6, -.55, -.65)
      ..cubicTo(-.5, -1.3, .45, -1.3, .55, -.65)
      ..cubicTo(1.1, -.6, 1.2, .5, .25, .2)
      ..close(),
    'leaf': Path()
      ..moveTo(-.8, .8)
      ..cubicTo(-1, -.65, .1, -1, .9, -.9)
      ..cubicTo(1, -.05, .65, 1, -.8, .8)
      ..close()
      ..moveTo(-.8, .8)
      ..lineTo(.65, -.65),
    'lotus': _lotus(),
    'diamond': Path()
      ..moveTo(-1, -.35)
      ..lineTo(-.5, -.9)
      ..lineTo(.5, -.9)
      ..lineTo(1, -.35)
      ..lineTo(0, 1)
      ..close()
      ..moveTo(-1, -.35)
      ..lineTo(1, -.35)
      ..moveTo(-.5, -.9)
      ..lineTo(-.3, -.35)
      ..lineTo(0, 1)
      ..lineTo(.3, -.35)
      ..lineTo(.5, -.9),
    'key': Path()
      ..addOval(const Rect.fromLTWH(-.95, -.85, .85, .85))
      ..moveTo(-.25, -.1)
      ..lineTo(.9, .9)
      ..lineTo(.95, .5)
      ..moveTo(.6, .65)
      ..lineTo(.85, .35),
    'mirror': Path()
      ..addOval(const Rect.fromLTWH(-.7, -1, 1.4, 1.5))
      ..moveTo(-.14, .5)
      ..lineTo(-.14, 1)
      ..lineTo(.14, 1)
      ..lineTo(.14, .5)
      ..moveTo(-.4, -.4)
      ..lineTo(.1, -.85),
    'mask': Path()
      ..moveTo(-.9, -.8)
      ..quadraticBezierTo(0, -.4, .9, -.8)
      ..cubicTo(1, .3, .3, 1, 0, 1)
      ..cubicTo(-.3, 1, -1, .3, -.9, -.8)
      ..close()
      ..addOval(const Rect.fromLTWH(-.65, -.1, .45, .2))
      ..addOval(const Rect.fromLTWH(.2, -.1, .45, .2))
      ..moveTo(-.35, .5)
      ..quadraticBezierTo(0, .85, .35, .5),
    'train': Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-.7, -1, 1.4, 1.7),
          const Radius.circular(.2),
        ),
      )
      ..addRect(const Rect.fromLTWH(-.48, -.7, .96, .6))
      ..addOval(const Rect.fromLTWH(-.5, .3, .2, .2))
      ..addOval(const Rect.fromLTWH(.3, .3, .2, .2))
      ..moveTo(-.4, .7)
      ..lineTo(-.7, 1)
      ..moveTo(.4, .7)
      ..lineTo(.7, 1),
    'plane': Path()
      ..moveTo(0, -1)
      ..lineTo(.15, -.3)
      ..lineTo(1, .2)
      ..lineTo(1, .4)
      ..lineTo(.15, .15)
      ..lineTo(.12, .7)
      ..lineTo(.45, .9)
      ..lineTo(.45, 1)
      ..lineTo(0, .88)
      ..lineTo(-.45, 1)
      ..lineTo(-.45, .9)
      ..lineTo(-.12, .7)
      ..lineTo(-.15, .15)
      ..lineTo(-1, .4)
      ..lineTo(-1, .2)
      ..lineTo(-.15, -.3)
      ..close(),
    'compass': Path()
      ..addOval(const Rect.fromLTWH(-1, -1, 2, 2))
      ..moveTo(.45, -.65)
      ..lineTo(.1, .1)
      ..lineTo(-.45, .65)
      ..lineTo(-.1, -.1)
      ..close(),
    'hand': Path()
      ..moveTo(-.6, 1)
      ..lineTo(-.9, .1)
      ..quadraticBezierTo(-1, -.2, -.75, -.1)
      ..lineTo(-.35, .35)
      ..lineTo(-.45, -.6)
      ..quadraticBezierTo(-.45, -.9, -.25, -.6)
      ..lineTo(-.1, -.05)
      ..lineTo(-.1, -.85)
      ..quadraticBezierTo(0, -1.1, .1, -.85)
      ..lineTo(.12, -.05)
      ..lineTo(.25, -.65)
      ..quadraticBezierTo(.4, -.9, .45, -.6)
      ..lineTo(.38, .05)
      ..lineTo(.6, -.35)
      ..quadraticBezierTo(.85, -.55, .75, -.15)
      ..lineTo(.6, .7)
      ..lineTo(.4, 1)
      ..close(),
    'musicNote': Path()
      ..moveTo(-.4, .65)
      ..lineTo(-.4, -.65)
      ..lineTo(.6, -.9)
      ..lineTo(.6, .45)
      ..addOval(const Rect.fromLTWH(-.8, .5, .4, .3))
      ..addOval(const Rect.fromLTWH(.2, .3, .4, .3))
      ..moveTo(-.4, -.3)
      ..lineTo(.6, -.55),
    'sun': Path()..addOval(const Rect.fromLTWH(-1, -1, 2, 2)),
    'moon': Path.combine(
      PathOperation.difference,
      Path()..addOval(const Rect.fromLTWH(-1, -1, 2, 2)),
      Path()..addOval(const Rect.fromLTWH(-.48, -.95, 1.6, 1.6)),
    ),
    'heart': Path()
      ..moveTo(0, 1)
      ..cubicTo(-2, 0, -1, -1.5, 0, -.4)
      ..cubicTo(1, -1.5, 2, 0, 0, 1),
    'rain': _rain(),
    'rose': _flower(),
    'flower': _flower(),
    'stars': _stars(),
    'water': _waves(),
    'smoke': _waves(),
    'city': _city(),
    'road': Path()
      ..moveTo(-1, 1)
      ..lineTo(-.12, -1)
      ..moveTo(1, 1)
      ..lineTo(.12, -1)
      ..moveTo(0, -.5)
      ..lineTo(0, -.1)
      ..moveTo(0, .25)
      ..lineTo(0, .8),
    'wings': Path()
      ..moveTo(0, .7)
      ..cubicTo(-.2, -.9, -1.3, -1, -1, -.25)
      ..lineTo(-.6, .2)
      ..lineTo(-.3, .15)
      ..close()
      ..moveTo(0, .7)
      ..cubicTo(.2, -.9, 1.3, -1, 1, -.25)
      ..lineTo(.6, .2)
      ..lineTo(.3, .15)
      ..close(),
    'eye': Path()
      ..moveTo(-1, 0)
      ..quadraticBezierTo(0, -1, 1, 0)
      ..quadraticBezierTo(0, 1, -1, 0)
      ..close()
      ..addOval(const Rect.fromLTWH(-.3, -.3, .6, .6)),
    'clock': Path()
      ..addOval(const Rect.fromLTWH(-1, -1, 2, 2))
      ..moveTo(0, -.65)
      ..lineTo(0, 0)
      ..lineTo(.45, .25),
    'crown': Path()
      ..moveTo(-.85, .65)
      ..lineTo(-1, -.55)
      ..lineTo(-.45, -.15)
      ..lineTo(0, -.9)
      ..lineTo(.45, -.15)
      ..lineTo(1, -.55)
      ..lineTo(.85, .65)
      ..close(),
    'lightning': Path()
      ..moveTo(.3, -1)
      ..lineTo(-.65, .15)
      ..lineTo(-.05, .1)
      ..lineTo(-.3, 1)
      ..lineTo(.7, -.25)
      ..lineTo(.05, -.2)
      ..close(),
    'brokenGlass': Path()
      ..moveTo(-.7, -.8)
      ..lineTo(-.1, -.25)
      ..lineTo(-.4, .8)
      ..close()
      ..moveTo(.1, -.9)
      ..lineTo(.9, -.45)
      ..lineTo(.25, .05)
      ..close()
      ..moveTo(.3, .3)
      ..lineTo(.9, .8)
      ..lineTo(-.05, .9)
      ..close(),
    'gun': Path()
      ..moveTo(-1, -.35)
      ..lineTo(.9, -.35)
      ..lineTo(.9, -.05)
      ..lineTo(-.05, -.05)
      ..lineTo(-.2, .75)
      ..lineTo(-.65, .75)
      ..lineTo(-.5, -.05)
      ..lineTo(-1, -.05)
      ..close(),
    'phone': Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-.5, -1, 1, 2),
          const Radius.circular(.12),
        ),
      )
      ..moveTo(-.22, -.72)
      ..lineTo(.22, -.72)
      ..addOval(const Rect.fromLTWH(-.06, .76, .12, .12)),
    'door': Path()
      ..addRect(const Rect.fromLTWH(-.65, -1, 1.3, 2))
      ..moveTo(-.65, -1)
      ..lineTo(.3, -.7)
      ..lineTo(.3, 1)
      ..lineTo(-.65, 1)
      ..addOval(const Rect.fromLTWH(.08, .12, .08, .08)),
    'flame': Path()
      ..moveTo(0, -1)
      ..cubicTo(.2, -.3, .8, -.4, .65, .45)
      ..cubicTo(.5, 1.1, -.65, 1.1, -.7, .35)
      ..cubicTo(-.75, -.15, -.2, -.3, 0, -1)
      ..close()
      ..moveTo(0, -.05)
      ..cubicTo(.3, .3, .2, .7, 0, .8)
      ..cubicTo(-.3, .65, -.28, .3, 0, -.05),
    'chain': Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, -.32, .75, .64),
          const Radius.circular(.3),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(.25, -.32, .75, .64),
          const Radius.circular(.3),
        ),
      )
      ..moveTo(-.22, -.4)
      ..lineTo(-.05, -.65)
      ..moveTo(.22, .4)
      ..lineTo(.05, .65),
  };
  static Path _ocean() {
    final p = Path()
      ..moveTo(-1, .6)
      ..cubicTo(-.7, .2, -.3, .3, -.1, .6)
      ..cubicTo(.5, -.65, 1, -.7, .8, -.1)
      ..cubicTo(.65, -.4, .45, 0, .5, .35)
      ..cubicTo(.7, .75, .95, .8, 1, .6);
    p.moveTo(-1, .9);
    p.cubicTo(-.3, .7, .3, 1.1, 1, .9);
    return p;
  }

  static Path _lotus() {
    final p = Path()
      ..moveTo(0, .65)
      ..cubicTo(-.45, .2, -.45, -.6, 0, -1)
      ..cubicTo(.45, -.6, .45, .2, 0, .65);
    for (final sign in [-1.0, 1.0]) {
      p.moveTo(0, .65);
      p.cubicTo(sign * .9, .6, sign * 1.15, -.1, sign * .8, -.5);
      p.cubicTo(sign * .1, -.2, sign * .15, .3, 0, .65);
    }
    return p;
  }

  static Path _flower() {
    final path = Path()
      ..moveTo(0, .1)
      ..lineTo(0, 1)
      ..moveTo(0, .6)
      ..quadraticBezierTo(-.6, .1, -.65, .5)
      ..quadraticBezierTo(-.3, .8, 0, .6);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      path.addOval(
        Rect.fromCircle(
          center: Offset(math.cos(angle) * .3, -.45 + math.sin(angle) * .3),
          radius: .28,
        ),
      );
    }
    return path;
  }

  static Path _stars() {
    final path = Path();
    for (final p in const [
      Offset(-.7, -.4),
      Offset(.4, -.8),
      Offset(.65, .5),
      Offset(-.3, .7),
    ]) {
      path.moveTo(p.dx - .14, p.dy);
      path.lineTo(p.dx + .14, p.dy);
      path.moveTo(p.dx, p.dy - .14);
      path.lineTo(p.dx, p.dy + .14);
    }
    return path;
  }

  static Path _waves() {
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final y = i * .5 - .5;
      path.moveTo(-1, y);
      path.cubicTo(-.4, y - .5, .4, y + .5, 1, y);
    }
    return path;
  }

  static Path _city() {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final h = .8 + (i % 3) * .4;
      path.addRect(Rect.fromLTWH(-1 + i * .4, 1 - h, .32, h));
    }
    return path;
  }

  static Path _rain() {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      path.moveTo(i * .25 - .625, -1);
      path.lineTo(i * .25 - .75, 1);
    }
    return path;
  }

  static String? select(String text) {
    final value = text.toLowerCase().replaceAll('’', "'");
    if (RegExp(
      r"\b(don't care|don't give|letting go|let go|goodbye)\b",
    ).hasMatch(value)) {
      return 'chain';
    }
    if (RegExp(r'\b(phone|call|calling)\b').hasMatch(value)) return 'phone';
    if (RegExp(r'\b(leave|leaving|door|walk out)\b').hasMatch(value)) {
      return 'door';
    }
    if (RegExp(r'\b(fire|burn|flame)\b').hasMatch(value)) return 'flame';
    if (RegExp(r'(ప్రేమ|காதல்)').hasMatch(value)) return 'heart';
    final match = RegExp(
      r'\b(moon|heart|love|sun|rain)\b',
    ).firstMatch(value)?.group(0);
    return match == 'love' ? 'heart' : match;
  }

  static void paint(
    Canvas canvas,
    String id,
    Offset center,
    double radius,
    double opacity,
  ) {
    final asset = _paths[id];
    if (asset == null) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    // A dimensional silhouette has a dark red offset face and a clear contour.
    canvas.drawPath(
      asset.shift(const Offset(.06, .08)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 / math.max(1, radius)
        ..color = const Color(0xff652626).withValues(alpha: opacity * .6),
    );
    if (id != 'rain') {
      canvas.drawPath(
        asset,
        Paint()
          ..color = const Color(
            0xffe95252,
          ).withValues(alpha: opacity * (id == 'raisedFist' ? .65 : .18)),
      );
    }
    canvas.drawPath(
      asset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / math.max(1, radius)
        ..color = const Color(
          0xffe95252,
        ).withValues(alpha: opacity.clamp(0, .32)),
    );
    canvas.restore();
  }
}
