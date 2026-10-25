// lib/ml/analyzing/analyze_timeline.dart
// Verbatim from scanine_analyzing.zip.
import 'dart:math' as math;

/// The Analyzing animation plays for at least this long (3.0 s timeline).
const int kMinAnalyzeMs = 3000;

/// Low-end devices finish the same beats in about 2 s.
const int kLowEndAnalyzeMs = 2000;

/// Reduced motion: 0.6 s cross-fade, then a short hold.
const int kReducedMotionMs = 1200;

enum AnalyzeMode { normal, lowEnd, reduced }

/// CSS-style cubic-bezier easing, pure Dart so it can be unit tested.
class CubicBezierEase {
  const CubicBezierEase(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double transform(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    var lo = 0.0;
    var hi = 1.0;
    var t = x;
    for (var i = 0; i < 40; i++) {
      final cx = _sample(x1, x2, t);
      if ((cx - x).abs() < 1e-7) break;
      if (cx < x) {
        lo = t;
      } else {
        hi = t;
      }
      t = (lo + hi) / 2;
    }
    return _sample(y1, y2, t);
  }

  static double _sample(double a, double b, double t) {
    final s = 1 - t;
    return 3 * s * s * t * a + 3 * s * t * t * b + t * t * t;
  }
}

/// Everything the painters need for one instant of the animation.
class AnalyzeFrame {
  const AnalyzeFrame({
    required this.scrim,
    required this.gridDraw,
    required this.gridAlpha,
    required this.frameAlpha,
    required this.scan,
    required this.scanAlpha,
    required this.reveal,
    required this.staggered,
    required this.groupAlpha,
    required this.cellsAlpha,
    required this.smoothAlpha,
    required this.handoff,
  });

  final double scrim;
  final double gridDraw;
  final double gridAlpha;
  final double frameAlpha;
  final double? scan;
  final double scanAlpha;
  final double reveal;
  final bool staggered;
  final double groupAlpha;
  final double cellsAlpha;
  final double smoothAlpha;
  final double handoff;

  static const double revealFeather = 0.06;

  double cellAlpha(double rowProgress) {
    if (!staggered) return groupAlpha;
    final a = (reveal - rowProgress) / revealFeather;
    return a < 0 ? 0 : (a > 1 ? 1 : a);
  }
}

abstract final class AnalyzeTimeline {
  static const double referenceSeconds = 3.0;
  static const double gridEnd = 0.45;
  static const double frameStart = 0.1;
  static const double frameEnd = 0.5;
  static const double scanStart = 0.5;
  static const double scanEnd = 1.7;
  static const double holdEnd = 2.4;
  static const double handoffEnd = 3.0;

  static const double introEnd = frameEnd / referenceSeconds;
  static const double revealFeather = 0.06;

  static const CubicBezierEase scanEase = CubicBezierEase(0.45, 0, 0.25, 1);

  static double phase(double v, double startSec, double endSec) {
    final p = (v * referenceSeconds - startSec) / (endSec - startSec);
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  static AnalyzeFrame frameAt(
    double v, {
    AnalyzeMode mode = AnalyzeMode.normal,
    double? waitLoop,
  }) {
    v = v < 0 ? 0 : (v > 1 ? 1 : v);

    if (mode == AnalyzeMode.reduced) {
      final fade = math.min(1.0, v / 0.5);
      return AnalyzeFrame(
        scrim: fade,
        gridDraw: 1,
        gridAlpha: fade,
        frameAlpha: fade,
        scan: null,
        scanAlpha: 0,
        reveal: 2,
        staggered: true,
        groupAlpha: 1,
        cellsAlpha: fade,
        smoothAlpha: 0,
        handoff: 0,
      );
    }

    final intro = phase(v, 0, gridEnd);
    final h = _smooth(phase(v, holdEnd, handoffEnd));
    final s = phase(v, scanStart, scanEnd);

    double? scan;
    var scanAlpha = 0.0;
    double reveal;
    if (waitLoop != null) {
      scan = scanEase.transform(waitLoop);
      scanAlpha = _edgeFade(waitLoop);
      reveal = 0;
    } else {
      final e = scanEase.transform(s);
      if (s > 0 && s < 1) {
        scan = e;
        scanAlpha = _edgeFade(s);
      }
      reveal =
          e +
          revealFeather *
              (((e - (1 - revealFeather)) / revealFeather).clamp(0.0, 1.0));
    }

    return AnalyzeFrame(
      scrim: intro,
      gridDraw: intro,
      gridAlpha: 1 - h,
      frameAlpha: phase(v, frameStart, frameEnd),
      scan: scan,
      scanAlpha: scanAlpha,
      reveal: reveal,
      staggered: mode != AnalyzeMode.lowEnd,
      groupAlpha: waitLoop != null ? 0 : phase(v, 0.9, 1.4),
      cellsAlpha: 1 - h,
      smoothAlpha: h,
      handoff: h,
    );
  }

  static double _smooth(double x) => x * x * (3 - 2 * x);

  static double _edgeFade(double s) {
    final a = math.min(s / 0.08, (1 - s) / 0.08);
    return a < 0 ? 0 : (a > 1 ? 1 : a);
  }
}
