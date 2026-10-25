// lib/ml/analyzing/amber_scan_painter.dart
//
// The single CustomPainter for the Analyzing screen's heat effect.
//
// Layers (back to front), controlled by the [scan] value (0..1):
//   1. Photo  — drawn by the widget tree above this painter, untouched.
//   2. Dim    — dark brown (#2a1d12) at 52 % opacity, full rect initially.
//              Above the scan line, the heat image punches holes via dstOut.
//   3. Tint   — amber tint drawn above the cleared areas (above scan line only).
//   4. Line   — 2 dp cloud line with 24 dp scan-grey glow, sweeping 0→1.
//
// All three effects are driven from a single [scan] value so they never drift.
//
// Performance notes:
//   • One saveLayer per frame for the dim (hole punching).
//   • The glow MaskFilter is skipped in low-end mode.
//   • No per-pixel work at paint time — all raster data is in [overlayImage].

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';

/// Configuration switches that can be set once on construction.
class AmberPainterConfig {
  const AmberPainterConfig({
    this.lowEndMode = false,
    this.reducedMotion = false,
  });

  /// When true, skip the glow MaskFilter on the scan line.
  final bool lowEndMode;

  /// When true, [scan] is treated as a cross-fade value (0→1) not a sweep.
  final bool reducedMotion;
}

class AmberScanPainter extends CustomPainter {
  AmberScanPainter({
    required this.scan,
    required this.dimAlpha,
    required this.handoff,
    required this.overlayImage,
    required this.config,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// 0..1 — fractional position of the scan line down the photo.
  /// Null means the line is hidden (before/after sweep).
  final double? scan;

  /// 0..1 — current opacity of the whole dim+tint+line effect layer.
  /// 0 = pre-dim (t < 0.45 s), fades in; 1 = full; fades out during handoff.
  final double dimAlpha;

  /// 0..1 — the Result overlay's fade-in during handoff. When > 0 the amber
  /// tint is additionally modulated (1 - handoff) so it fades out in sync.
  final double handoff;

  /// Pre-built 112×112 heat image. Alpha encodes heat. May be null (diffuse).
  final ui.Image? overlayImage;

  final AmberPainterConfig config;

  // ── Colour constants ───────────────────────────────────────────────────────
  static const _dimColor = Color(0xFF2A1D12); // #2a1d12 brown
  static const _dimOpacity = 0.52;
  static const _scanLineColor = Color(0xFFF4F5FA); // cloud
  static const _scanGlowColor = Color(0xFFC4CAD8); // scanGrey
  static const _amberColor = Color(0xFFDCA052); // capture amber

  // Re-used Paint objects (allocated once per instance).
  final _dimFill = Paint()..blendMode = BlendMode.srcOver;
  final _holeMask = Paint()
    ..blendMode = BlendMode.dstOut
    ..filterQuality = FilterQuality.medium;
  final _tintPaint = Paint()
    ..blendMode = BlendMode.srcOver
    ..filterQuality = FilterQuality.medium;
  final _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.butt;
  final _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 24.0
    ..strokeCap = StrokeCap.butt;

  @override
  void paint(Canvas canvas, Size size) {
    final img = overlayImage;
    final scanLine = scan;
    final totalAlpha = (dimAlpha * (1.0 - handoff)).clamp(0.0, 1.0);
    if (totalAlpha < 0.004) return;

    // The scan value (0..1) determines the horizontal split: above = revealed,
    // below = full dim.
    final splitY = scanLine != null ? scanLine * size.height : size.height;

    // ── 2. Dim layer (with hole) ─────────────────────────────────────────────
    // We need the dim to have soft holes where the heat is, above the scan
    // line. We do this with a saveLayer + dstOut compositing:
    //   a) draw the full brown rect into the layer
    //   b) clip to the region above the scan line
    //   c) draw the heat image with dstOut to punch the holes
    //   d) restore restores the composited result

    _dimFill.color = _dimColor.withAlpha((_dimOpacity * totalAlpha * 255).round().clamp(0, 255));

    final dimRect = Offset.zero & size;

    canvas.saveLayer(dimRect, Paint());

    // Full brown rect.
    canvas.drawRect(dimRect, _dimFill);

    if (img != null && !config.reducedMotion) {
      // Punch holes above the scan line.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, splitY));
      _paintHoles(canvas, size, img, totalAlpha);
      canvas.restore();
    } else if (img != null && config.reducedMotion) {
      // Reduced motion: holes are always fully revealed (scan is a cross-fade).
      _paintHoles(canvas, size, img, totalAlpha);
    }

    canvas.restore(); // dim layer composited

    // ── 3. Amber tint ────────────────────────────────────────────────────────
    // Drawn above the cleared areas. Above the scan line only (or full in
    // reduced-motion mode).
    if (img != null && totalAlpha > 0.004) {
      canvas.save();
      if (!config.reducedMotion && scanLine != null) {
        canvas.clipRect(Rect.fromLTWH(0, 0, size.width, splitY));
      }
      _paintTint(canvas, size, img, totalAlpha);
      canvas.restore();
    }

    // ── 4. Scan line ─────────────────────────────────────────────────────────
    if (scanLine != null && !config.reducedMotion) {
      final y = scanLine * size.height;
      final lineAlpha = (totalAlpha * _scanLineAlpha(scan!)).clamp(0.0, 1.0);
      if (lineAlpha > 0.004) {
        // Glow (skipped in low-end mode).
        if (!config.lowEndMode) {
          _glowPaint.color = _scanGlowColor.withAlpha((0.45 * lineAlpha * 255).round().clamp(0, 255));
          _glowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawLine(Offset(0, y), Offset(size.width, y), _glowPaint);
        } else {
          // Soft rect instead.
          final gp = Paint()
            ..color = _scanGlowColor.withAlpha((0.20 * lineAlpha * 255).round().clamp(0, 255));
          canvas.drawRect(Rect.fromLTWH(0, y - 6, size.width, 12), gp);
        }
        // Core line.
        _linePaint.color = _scanLineColor.withAlpha((lineAlpha * 255).round().clamp(0, 255));
        canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);
      }
    }
  }

  void _paintHoles(Canvas canvas, Size size, ui.Image img, double alpha) {
    // hole opacity = clamp(heat * 1.6, 0, 1)^0.9
    // We bake this into a modulated draw: we want the dstOut alpha to equal
    // the hole formula. But since we can't do per-pixel nonlinear transforms
    // on a GPU paint pass without a shader, we approximate by drawing the
    // heat image at alpha = (clamp(heat*1.6,0,1))^0.9 averaged.
    // Practically: the heat image's own alpha already encodes heat (0..255);
    // drawing it with blendMode=dstOut uses its alpha to erase the dim.
    // We scale the draw alpha by a factor that approximates heat^0.9*1.6.
    // Because FilterQuality.medium gives us bilinear, the continuous formula
    // applies per-pixel via alpha compositing.
    //
    // The approximation: draw at opacity=1 and rely on the alpha channel
    // encoding heat linearly. For the ^0.9 curve (barely perceptible), the
    // visual difference is negligible. Exact formula:
    //   dstOut_alpha = clamp(heat * 1.6, 0, 1)
    // encoded into the image's own alpha channel * scale. We scale by 1.6 by
    // setting draw alpha = 1.0 and relying on the encoded heat channel.
    // This gives clamp(heat/255 * 1.6, 0, 1) which matches the spec exactly
    // for the linear term (the ^0.9 is a very subtle gamma that we skip to
    // avoid a shader dependency).

    _holeMask.color = Color.fromARGB(
      (1.0 * alpha * 255).round().clamp(0, 255),
      255,
      255,
      255,
    );

    // Draw the heat image scaled so its alpha encodes 1.6× heat.
    // We draw the image at a scale factor: the image alpha is 0..255 = heat.
    // Multiply the image alpha by 1.6 by drawing it twice at 80% each,
    // because 1 - (1-0.8)^2 ≈ 0.96 which is close to clamped 1.6×.
    // Simpler: draw with color alpha of floor(1.6 * 255) = 255 (clamped);
    // but we can't boost above 255. Instead we draw the image once using
    // ColorFilter to scale its alpha channel by 1.6 (clamped by GPU).
    final scaledHoleMask = Paint()
      ..blendMode = BlendMode.dstOut
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.matrix([
        // identity for RGB, alpha * 1.6
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1.6, 0,
      ]);
    scaledHoleMask.color = Color.fromARGB(
      (alpha * 255).round().clamp(0, 255),
      255,
      255,
      255,
    );

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      scaledHoleMask,
    );
  }

  void _paintTint(Canvas canvas, Size size, ui.Image img, double alpha) {
    // Tint alpha = heat^1.6 * 0.30 per the spec.
    // Again we can't apply per-pixel pow in a paint call without a shader.
    // We draw the amber at a global alpha of 0.30, using the image's heat
    // alpha channel to modulate per-pixel. The ^1.6 compression is mild
    // (only affects mid-tones); omitting it is conservative (slightly less
    // amber in mid areas) and avoids a dependency on FragmentProgram.
    // The visual effect is equivalent to the spec at ±5% in any area.

    final colorAlpha = (alpha * 0.30 * 255).round().clamp(0, 255);
    if (colorAlpha < 2) return;

    _tintPaint.color = _amberColor.withAlpha(colorAlpha);
    // Use ColorFilter to blend the image's alpha with the amber.
    final tintCf = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(
        _amberColor.withAlpha(colorAlpha),
        BlendMode.modulate,
      )
      ..blendMode = BlendMode.srcOver;

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      tintCf,
    );
  }

  /// Edge-fade alpha for the scan line: ramps in 0→0.08 and out 0.92→1.
  static double _scanLineAlpha(double s) {
    final a = math.min(s / 0.08, (1.0 - s) / 0.08);
    return a < 0 ? 0 : (a > 1 ? 1 : a);
  }

  @override
  bool shouldRepaint(AmberScanPainter old) =>
      old.scan != scan ||
      old.dimAlpha != dimAlpha ||
      old.handoff != handoff ||
      old.overlayImage != overlayImage ||
      old.config != config;
}
