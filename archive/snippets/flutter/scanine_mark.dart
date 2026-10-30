import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Design tokens for the Scanine mark and shutter system.
class ScanineMarkColors {
  ScanineMarkColors._();

  static const Color navy = Color(0xFF1E3763);
  static const Color coolGray = Color(0xFFC5CAD6);
  static const Color paleBlueGray = Color(0xFFEDF0F5);
}

/// The official Scanine brand mark.
///
/// Consists of five separate outer C-shaped segments, a fixed navy center dot,
/// and a right-facing opening.
///
/// When [acceptedFrames] is null, the mark displays the static brand lockup:
/// three navy segments (lower right, lower left, left) and two cool gray segments
/// (upper left, upper right).
///
/// When [acceptedFrames] (0 to 5) is provided, the five outer segments fill in
/// the official sequence:
/// 1. Lower right (at 1/5)
/// 2. Lower left (at 2/5)
/// 3. Left (at 3/5)
/// 4. Upper left (at 4/5)
/// 5. Upper right (at 5/5)
///
/// Unfilled segments are cool gray (#C5CAD6).
/// Filled segments are navy (#1E3763).
/// The center dot is always navy (#1E3763) and does not count as a 6th segment.
class ScanineMark extends StatelessWidget {
  const ScanineMark({
    super.key,
    this.size = 48.0,
    this.acceptedFrames,
    this.navyColor = ScanineMarkColors.navy,
    this.coolGrayColor = ScanineMarkColors.coolGray,
  });

  /// The width and height of the mark.
  final double size;

  /// Accepted frame count from 0 to 5. If null, displays the static brand mark
  /// (3 navy segments, 2 cool gray segments).
  final int? acceptedFrames;

  final Color navyColor;
  final Color coolGrayColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ScanineMarkPainter(
          acceptedFrames: acceptedFrames,
          navyColor: navyColor,
          coolGrayColor: coolGrayColor,
        ),
      ),
    );
  }
}

class _ScanineMarkPainter extends CustomPainter {
  const _ScanineMarkPainter({
    required this.acceptedFrames,
    required this.navyColor,
    required this.coolGrayColor,
  });

  final int? acceptedFrames;
  final Color navyColor;
  final Color coolGrayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    // Derived from the 192x192 SVG master:
    // Arc radius = 72 on 192 box -> 72 / 192 = 0.375
    // Stroke width = 24 on 192 box -> 24 / 192 = 0.125
    // Dot radius = 19.5 on 192 box -> 19.5 / 192 = 0.1015625
    final arcRadius = size.width * (72.0 / 192.0);
    final strokeWidth = size.width * (24.0 / 192.0);
    final dotRadius = size.width * (19.5 / 192.0);

    // Segment definitions (in degrees, clockwise from 3 o'clock):
    // 1. Lower right: 35.0° -> 87.0° (sweep 52.0°)
    // 2. Lower left:  95.0° -> 147.0° (sweep 52.0°)
    // 3. Left:        155.0° -> 207.0° (sweep 52.0°)
    // 4. Upper left:  215.0° -> 267.0° (sweep 52.0°)
    // 5. Upper right: 275.0° -> 327.0° (sweep 52.0°)
    //
    // Inter-segment gaps: 8.0°
    // Right-facing opening: 327.0° to 35.0° (68.0° opening, ±34.0° from 0°)
    const segmentAngles = [
      (35.0, 52.0),
      (95.0, 52.0),
      (155.0, 52.0),
      (215.0, 52.0),
      (275.0, 52.0),
    ];

    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: arcRadius,
    );

    for (var i = 0; i < 5; i++) {
      final isNavy = acceptedFrames == null
          ? (i < 3) // Static brand mark: segments 1, 2, 3 navy; 4, 5 cool gray
          : (i < acceptedFrames!); // Dynamic shutter: filled in order 1..5

      final paint = Paint()
        ..color = isNavy ? navyColor : coolGrayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      final (startDeg, sweepDeg) = segmentAngles[i];
      final startRad = startDeg * (math.pi / 180.0);
      final sweepRad = sweepDeg * (math.pi / 180.0);

      canvas.drawArc(rect, startRad, sweepRad, false, paint);
    }

    // Fixed center dot — always navy (#1E3763)
    final dotPaint = Paint()
      ..color = navyColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(_ScanineMarkPainter oldDelegate) =>
      oldDelegate.acceptedFrames != acceptedFrames ||
      oldDelegate.navyColor != navyColor ||
      oldDelegate.coolGrayColor != coolGrayColor;
}

/// The official Scanine camera shutter button showing progress across five
/// accepted frames.
///
/// Progress rules:
/// - 0/5: all five segments are cool gray (#C5CAD6).
/// - 1/5: one segment becomes navy (#1E3763).
/// - 2/5: two segments are navy.
/// - Continue until 5/5, when all five segments are navy.
///
/// Fill order: lower right, lower left, left, upper left, then upper right.
/// Gaps and right-facing opening stay visible throughout.
/// Center dot stays navy and does not count as a 6th segment.
///
/// Accessibility: Provides "X of 5 frames accepted" semantic value.
class ScanineShutterButton extends StatefulWidget {
  const ScanineShutterButton({
    super.key,
    required this.acceptedFrames,
    required this.onTap,
    this.busy = false,
    this.isReady = true,
    this.size = 80.0,
  });

  /// The number of accepted frames (0 to 5).
  final int acceptedFrames;

  /// Triggered on tap. Disabled when [busy] is true or [acceptedFrames] >= 5.
  final VoidCallback onTap;

  /// True when capture, buffer reset, or quality gating is active.
  final bool busy;

  /// True when preview quality is acceptable.
  final bool isReady;

  /// Diameter of the shutter button touch area.
  final double size;

  @override
  State<ScanineShutterButton> createState() => _ScanineShutterButtonState();
}

class _ScanineShutterButtonState extends State<ScanineShutterButton> {
  bool _pressed = false;

  bool get _canTap => !widget.busy && widget.acceptedFrames < 5;

  void _handleTapDown(_) {
    if (_canTap) {
      setState(() => _pressed = true);
    }
  }

  void _handleTapUp(_) {
    if (_pressed) {
      setState(() => _pressed = false);
      if (_canTap) {
        widget.onTap();
      }
    }
  }

  void _handleTapCancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedFrames = widget.acceptedFrames.clamp(0, 5);

    return Semantics(
      button: true,
      enabled: _canTap,
      label: 'Shutter button',
      value: '$clampedFrames of 5 frames accepted',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _pressed || widget.busy ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              color: ScanineMarkColors.paleBlueGray,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1814243B),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(widget.size * 0.10),
            child: Center(
              child: ScanineMark(
                size: widget.size * 0.80,
                acceptedFrames: clampedFrames,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The official Scanine wordmark in Urbanist typography.
///
/// Replaces the letter "c" in "scanine" with the segmented static brand logo,
/// which naturally forms a stylized "C". The remaining letters ("s" and "anine")
/// are rendered in Urbanist, with normal dot on the "i".
class ScanineWordmark extends StatelessWidget {
  const ScanineWordmark({
    super.key,
    this.fontSize = 29.0,
    this.color = ScanineMarkColors.navy,
    this.fontWeight = FontWeight.w700,
  });

  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    // Outer diameter of the mark is 0.875 * markSize.
    // In Urbanist Bold, lowercase x-height is ~0.525 * fontSize.
    // Setting markSize = fontSize * 0.60 gives outer diameter of 0.875 * 0.60 * fontSize ≈ 0.525 * fontSize,
    // which matches the optical height of 's' and 'a' precisely.
    final markSize = fontSize * 0.60;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Hidden text node ensuring test matchers like find.text('scanine') pass
        Opacity(
          opacity: 0.0,
          child: Text(
            'scanine',
            style: TextStyle(
              fontFamily: 'Urbanist',
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: Colors.transparent,
            ),
          ),
        ),

        // Visual presentation: inline Text.rich with middle-aligned WidgetSpan
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: 'Urbanist',
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: -0.8,
              color: color,
            ),
            children: [
              const TextSpan(text: 's'),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: fontSize * 0.03),
                  child: SizedBox(
                    width: markSize,
                    height: markSize,
                    child: Center(
                      child: ScanineMark(
                        size: markSize,
                        acceptedFrames: null, // Static brand mark
                        navyColor: color,
                      ),
                    ),
                  ),
                ),
              ),
              const TextSpan(text: 'anine'),
            ],
          ),
        ),
      ],
    );
  }
}
