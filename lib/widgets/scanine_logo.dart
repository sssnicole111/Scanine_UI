import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Renders the official Scanine brand-mark icon (the segmented C with a
/// centre dot) as a standalone widget with a **transparent background**.
///
/// Drop-in replacement for any widget that was previously wrapping the logo
/// inside a coloured container. Set [size] to control the diameter; colours
/// default to the Scanine navy / cool-grey palette.
class ScanineLogoMark extends StatelessWidget {
  const ScanineLogoMark({
    super.key,
    this.size = 40,
    this.navyColor = const Color(0xFF1E3763),
    this.grayColor = const Color(0xFFC5CAD6),
  });

  final double size;
  final Color navyColor;
  final Color grayColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(navy: navyColor, gray: grayColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.navy, required this.gray});

  final Color navy;
  final Color gray;

  // Segment definitions matching the SVG (start °, sweep °).
  // Angles are measured clockwise from 3 o'clock (standard Flutter arc).
  static const _segs = [
    (35.0, 52.0, true),  // lower-right  — navy
    (95.0, 52.0, true),  // lower-left   — navy
    (155.0, 52.0, true), // left          — navy
    (215.0, 52.0, false), // upper-left  — gray
    (275.0, 52.0, false), // upper-right — gray
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.shortestSide / 2;
    canvas.translate(r, r);

    // Arc radius is 72/192 of the total icon size (matches SVG viewBox ratio).
    final double arcR = r * (72.0 / 96.0);
    final double strokeW = r * (24.0 / 96.0);
    final double dotR = r * (19.5 / 96.0);

    final rect = Rect.fromCircle(center: Offset.zero, radius: arcR);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    for (final (startDeg, sweepDeg, isNavy) in _segs) {
      paint.color = isNavy ? navy : gray;
      final startRad = startDeg * (math.pi / 180.0);
      final sweepRad = sweepDeg * (math.pi / 180.0);
      canvas.drawArc(rect, startRad, sweepRad, false, paint);
    }

    // Centre dot
    canvas.drawCircle(
      Offset.zero,
      dotR,
      Paint()
        ..color = navy
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.navy != navy || old.gray != gray;
}

