// lib/ml/analyzing/frame_painter.dart
// Verbatim from scanine_analyzing.zip — imports adapted.
import 'package:flutter/material.dart';

import 'analyze_clock.dart';
import 'analyzing_tokens.dart';

/// Layer 5: four rounded corner brackets + edge ticks.
class FramePainter extends CustomPainter {
  FramePainter({required this.clock, required this.tokens})
    : super(repaint: clock.repaint);

  final AnalyzeClock clock;
  final AnalyzingTokens tokens;

  static const double inset = 14;
  static const double arm = 28;
  static const double radius = 10;
  static const double tick = 8;
  static const double stroke = 2;

  final Paint _brackets = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _ticks = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round;

  Size? _pathSize;
  Path _bracketPath = Path();
  Path _tickPath = Path();

  void _ensurePaths(Size s) {
    if (_pathSize == s) return;
    _pathSize = s;
    final w = s.width;
    final h = s.height;
    const i = inset;
    const a = arm;
    const r = radius;
    const rad = Radius.circular(r);
    _bracketPath = Path()
      // top left
      ..moveTo(i, i + a)
      ..lineTo(i, i + r)
      ..arcToPoint(const Offset(i + r, i), radius: rad)
      ..lineTo(i + a, i)
      // top right
      ..moveTo(w - i - a, i)
      ..lineTo(w - i - r, i)
      ..arcToPoint(Offset(w - i, i + r), radius: rad)
      ..lineTo(w - i, i + a)
      // bottom right
      ..moveTo(w - i, h - i - a)
      ..lineTo(w - i, h - i - r)
      ..arcToPoint(Offset(w - i - r, h - i), radius: rad)
      ..lineTo(w - i - a, h - i)
      // bottom left
      ..moveTo(i + a, h - i)
      ..lineTo(i + r, h - i)
      ..arcToPoint(Offset(i, h - i - r), radius: rad)
      ..lineTo(i, h - i - a);
    _tickPath = Path()
      ..moveTo(w / 2, i)
      ..lineTo(w / 2, i + tick)
      ..moveTo(w / 2, h - i)
      ..lineTo(w / 2, h - i - tick)
      ..moveTo(i, h / 2)
      ..lineTo(i + tick, h / 2)
      ..moveTo(w - i, h / 2)
      ..lineTo(w - i - tick, h / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    clock.guard(() {
      final f = clock.frame();
      if (f.frameAlpha <= 0) return;
      _ensurePaths(size);
      _brackets.color = withOpacityF(tokens.cloud, f.frameAlpha);
      _ticks.color = withOpacityF(tokens.cloud, 0.5 * f.frameAlpha);
      canvas.drawPath(_tickPath, _ticks);
      canvas.drawPath(_bracketPath, _brackets);
    });
  }

  @override
  bool shouldRepaint(FramePainter old) =>
      old.clock != clock || old.tokens != tokens;
}
