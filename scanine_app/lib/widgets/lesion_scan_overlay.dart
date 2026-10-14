// lib/widgets/lesion_scan_overlay.dart
//
// A biometric HUD scanning overlay widget for Flutter.
// Renders full-width photo with a translucent cyan grid, a sweeping cyan scan line,
// corner progress badge gauge, corner brackets, and discovered Grad-CAM lesion regions
// featuring glowing contours, pulsing target nodes, and orthogonal leader readouts.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ml/gradcam_contours.dart';

// ── Colors ─────────────────────────────────────────────────────────────────
const Color _scanLine = Color(0xFF00F0FF); // Electric Cyan
const Color _scanWake = Color(0xFF00A8FF); // Deep Cyan Wake
const Color _hudCyan = Color(0xFF00F0FF); // Cyan HUD Accent

// ── Timing ─────────────────────────────────────────────────────────────────
const Duration _sweepDuration = Duration(milliseconds: 2800);
const Duration _settlePause = Duration(milliseconds: 600);
const Duration _outDuration = Duration(milliseconds: 350);

// Scan-line easing: smooth deceleration.
const Cubic _settle = Cubic(0.3, 0.0, 0.1, 1.0);

const double _slitH = 3.0; // Height of scan line in px
const double _wakeH = 80.0; // Height of wake gradient

// Region outline pulse
const Duration _pulsePeriod = Duration(milliseconds: 900);

// ── Status messages ─────────────────────────────────────────────────────────
const List<String> _statusMessages = [
  'SCANNING SKIN SURFACE\u2026',
  'IDENTIFYING AFFECTED AREAS\u2026',
  'ANALYSING TEXTURE PATTERNS\u2026',
  'MAPPING HIGH-ACTIVATION ZONES\u2026',
  'FINALISING ASSESSMENT\u2026',
];

/// Sweeps a scan line over [imagePath] and highlights Grad-CAM [regions].
class LesionScanOverlay extends StatefulWidget {
  const LesionScanOverlay({
    super.key,
    required this.imagePath,
    required this.regions,
    required this.onFinished,
  });

  final String imagePath;
  final List<CamRegion> regions;
  final VoidCallback onFinished;

  @override
  State<LesionScanOverlay> createState() => _LesionScanOverlayState();
}

class _LesionScanOverlayState extends State<LesionScanOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _sweep;
  late final AnimationController _pulse;

  int _msgIdx = 0;
  final Set<int> _revealed = {};
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _sweep = AnimationController(vsync: this, duration: _sweepDuration)
      ..addListener(_onSweepTick)
      ..addStatusListener(_onSweepStatus)
      ..forward();

    _pulse = AnimationController(vsync: this, duration: _pulsePeriod)
      ..repeat(reverse: true);

    _scheduleNextMsg();
  }

  void _scheduleNextMsg() {
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _msgIdx = (_msgIdx + 1).clamp(0, _statusMessages.length - 1);
      });
      if (_msgIdx < _statusMessages.length - 1) _scheduleNextMsg();
    });
  }

  void _onSweepTick() {
    final t = _settle.transform(_sweep.value);
    for (var i = 0; i < widget.regions.length; i++) {
      if (!_revealed.contains(i) && t >= widget.regions[i].scanMid) {
        setState(() => _revealed.add(i));
      }
    }
  }

  void _onSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _navigating) return;
    _navigating = true;

    if (mounted) {
      setState(() {
        for (var i = 0; i < widget.regions.length; i++) {
          _revealed.add(i);
        }
      });
    }

    Future<void>.delayed(_settlePause).then((_) {
      if (!mounted) return;
      Future<void>.delayed(_outDuration).then((_) {
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: [
        // ── Photo with subtle dark overlay ───────────────────────────
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
              Container(color: const Color(0x3B071124)), // 23% navy tint
            ],
          ),
        ),

        // ── Scan HUD overlay painter ─────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_sweep, _pulse]),
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanPainter(
                  sweepT: _settle.transform(_sweep.value),
                  pulseT: _pulse.value,
                  regions: widget.regions,
                  revealedIndices: Set<int>.from(_revealed),
                ),
              );
            },
          ),
        ),

        // ── Disclaimer badge ─────────────────────────────────────────────
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE6071124),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x6600F0FF), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _hudCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'SCREENING AID — NOT A DIAGNOSIS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00F0FF),
                      letterSpacing: -0.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Status label & bottom progress bar ────────────────────────
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _statusMessages[_msgIdx],
                  key: ValueKey<int>(_msgIdx),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00F0FF),
                    letterSpacing: -0.2,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(
                        color: Color(0xFF071124),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 180,
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _sweep.value,
                      minHeight: 3,
                      backgroundColor: const Color(0x3300F0FF),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_scanLine),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]);
    });
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _ScanPainter extends CustomPainter {
  _ScanPainter({
    required this.sweepT,
    required this.pulseT,
    required this.regions,
    required this.revealedIndices,
  });

  final double sweepT;
  final double pulseT;
  final List<CamRegion> regions;
  final Set<int> revealedIndices;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Translucent Cyan Grid Overlay
    final gridPaint = Paint()
      ..color = const Color(0x1400F0FF) // ~8% opacity cyan
      ..strokeWidth = 1.0;

    const gridSize = 40.0;
    for (double x = 0; x <= w; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y <= h; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 2. Corner HUD Brackets
    _drawHudCorners(canvas, size);

    // 3. Corner Progress Ring Badge Gauge
    _drawProgressBadge(canvas, Offset(w - 50, 65), sweepT);

    final lineY = sweepT.clamp(0.0, 1.0) * h;

    // 4. Discovered Regions with glowing contours, node center points & HUD cards
    for (var i = 0; i < regions.length; i++) {
      if (!revealedIndices.contains(i)) continue;

      final r = regions[i];
      final (pl, pt, pr, pb) = r.toPixels(w, h);
      final rect = Rect.fromLTRB(pl, pt, pr, pb);

      final cx = (pl + pr) / 2;
      final cy = (pt + pb) / 2;

      final intensity = 0.65 + 0.35 * r.peakActivation;
      final pulseFactor = math.sin(pulseT * math.pi);

      // Pulsing glow fill
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFF00F0FF)
              .withValues(alpha: (0.08 + 0.12 * pulseFactor) * intensity),
      );

      // Outer blur outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFF00F0FF)
              .withValues(alpha: (0.75 + 0.25 * pulseFactor) * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );

      // Crisp inner outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF00F0FF)
              .withValues(alpha: (0.9 * intensity).clamp(0, 1)),
      );

      // Node point target at center
      final nodeRadius = 5.0 + 2.5 * pulseFactor;
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF00F0FF).withValues(alpha: 0.5),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        nodeRadius,
        Paint()..color = const Color(0xFF00F0FF),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        2.0,
        Paint()..color = Colors.white,
      );

      // Orthogonal Leader Line & HUD Label Card
      final isRightSide = cx < w * 0.6;
      final leaderX1 = isRightSide ? cx + 25.0 : cx - 25.0;
      final leaderX2 = isRightSide ? leaderX1 + 25.0 : leaderX1 - 25.0;
      final leaderY2 = cy - 18.0;

      final leaderPath = Path()
        ..moveTo(cx, cy)
        ..lineTo(leaderX1, cy)
        ..lineTo(leaderX2, leaderY2);

      canvas.drawPath(
        leaderPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xCC00F0FF),
      );

      // Terminal dot
      canvas.drawCircle(
          Offset(leaderX2, leaderY2), 2.5, Paint()..color = const Color(0xFF00F0FF));

      // HUD Tag text card
      final labelText = 'REGION 0${i + 1} // HUD_ACTIVE';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Color(0xFF00F0FF),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tagW = textPainter.width + 12;
      final tagH = textPainter.height + 6;
      final tagLeft = isRightSide ? leaderX2 + 4 : leaderX2 - tagW - 4;
      final tagTop = leaderY2 - tagH / 2;

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagW, tagH),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        tagRect,
        Paint()..color = const Color(0xEB071124),
      );
      canvas.drawRRect(
        tagRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0x8000F0FF),
      );

      textPainter.paint(canvas, Offset(tagLeft + 6, tagTop + 3));
    }

    // 5. Scan Line & Wake Slit
    final edgeFade = math.min(sweepT / 0.04, 1.0) *
        math.min((1.0 - sweepT) / 0.04, 1.0);

    if (edgeFade > 0) {
      final wakeTop = math.max(0.0, lineY - _wakeH);
      canvas.drawRect(
        Rect.fromLTRB(0, wakeTop, w, lineY),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, wakeTop),
            Offset(0, lineY),
            [
              _scanWake.withValues(alpha: 0),
              _scanWake.withValues(alpha: 0.28 * edgeFade),
            ],
          ),
      );

      canvas.drawRect(
        Rect.fromLTRB(0, lineY - _slitH / 2, w, lineY + _slitH / 2),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, lineY - _slitH / 2),
            Offset(0, lineY + _slitH / 2),
            [
              const Color(0xFF00F0FF).withValues(alpha: 0),
              const Color(0xFF00F0FF).withValues(alpha: 0.95 * edgeFade),
              const Color(0xFFFFFFFF).withValues(alpha: 1.0 * edgeFade),
              const Color(0xFF00F0FF).withValues(alpha: 0.95 * edgeFade),
              const Color(0xFF00F0FF).withValues(alpha: 0),
            ],
            const [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
      );
    }
  }

  void _drawHudCorners(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0x8000F0FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const len = 16.0;
    const pad = 16.0;

    // Top-Left corner
    canvas.drawPath(
        Path()
          ..moveTo(pad, pad + len)
          ..lineTo(pad, pad)
          ..lineTo(pad + len, pad),
        paint);
    // Top-Right corner
    canvas.drawPath(
        Path()
          ..moveTo(w - pad - len, pad)
          ..lineTo(w - pad, pad)
          ..lineTo(w - pad, pad + len),
        paint);
    // Bottom-Left corner
    canvas.drawPath(
        Path()
          ..moveTo(pad, h - pad - len)
          ..lineTo(pad, h - pad)
          ..lineTo(pad + len, h - pad),
        paint);
    // Bottom-Right corner
    canvas.drawPath(
        Path()
          ..moveTo(w - pad - len, h - pad)
          ..lineTo(w - pad, h - pad)
          ..lineTo(w - pad, h - pad - len),
        paint);
  }

  void _drawProgressBadge(Canvas canvas, Offset center, double progress) {
    const radius = 22.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xE6071124),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0x3300F0FF),
    );

    final sweepAngle = progress.clamp(0.0, 1.0) * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF00F0FF)
        ..strokeCap = StrokeCap.round,
    );

    final pct = (progress * 100).toInt();
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: const TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
          center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.sweepT != sweepT ||
      old.pulseT != pulseT ||
      !setEquals(old.revealedIndices, revealedIndices);
}
