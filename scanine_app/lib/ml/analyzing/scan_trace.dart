// lib/ml/analyzing/scan_trace.dart
// Ported from scanine_analyzing.zip — imports adapted for scanine_app layout.
import 'dart:typed_data';

import 'input_mapping.dart';

/// The Grad-CAM heat for one scan, laid over the whole captured image.
///
/// Built once, at the end of inference, then passed to the Analyzing screen
/// and on to Result. Nothing downstream recomputes it.
class ScanTrace {
  ScanTrace({required this.heat, required this.coverage, required this.diffuse})
    : assert(
        heat.length == resolution * resolution,
        'heat must be $resolution x $resolution',
      );

  /// A trace that lights nothing — used when the trace could not be built.
  factory ScanTrace.empty() => ScanTrace(
    heat: Uint8List(resolution * resolution),
    coverage: 0,
    diffuse: true,
  );

  /// Side of the heat grid.
  static const int resolution = 56;

  /// A cell counts as "covered" at or above this fraction of the maximum.
  static const double coverageLevel = 0.5;

  /// Above this coverage nothing stands out — the map is called diffuse.
  static const double diffuseCoverage = 0.6;

  /// A raw map whose maximum is below this is treated as flat / empty.
  static const double flatEpsilon = 1e-6;

  /// 56x56, row-major, 0..255, covering the full captured image.
  final Uint8List heat;

  /// Fraction of the cells the model saw that are >= [coverageLevel].
  final double coverage;

  /// True when nothing stands out. The Analyzing screen lights nothing.
  final bool diffuse;

  /// Heat of one cell, 0..1.
  double cell(int row, int col) => heat[row * resolution + col] / 255.0;

  /// Bilinear heat at a point of the image, [x] and [y] in 0..1, result 0..1.
  double valueAt(double x, double y) {
    final fx = _clamp(x * resolution - 0.5, 0, resolution - 1.0);
    final fy = _clamp(y * resolution - 0.5, 0, resolution - 1.0);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1 < resolution ? x0 + 1 : x0;
    final y1 = y0 + 1 < resolution ? y0 + 1 : y0;
    final tx = fx - x0;
    final ty = fy - y0;
    final top = cell(y0, x0) * (1 - tx) + cell(y0, x1) * tx;
    final bottom = cell(y1, x0) * (1 - tx) + cell(y1, x1) * tx;
    return top * (1 - ty) + bottom * ty;
  }

  /// Builds a trace from a raw Grad-CAM map.
  ///
  /// [cam] is row-major, [camHeight] rows of [camWidth] values (7x7 for
  /// MobileNetV3-Small). The classifier's [FrameResult.cam] is already
  /// ReLU'd and normalised, so pass it directly.
  static ScanTrace fromCam({
    required List<double> cam,
    required int camWidth,
    required int camHeight,
    InputMapping mapping = const InputMapping.stretch(),
  }) {
    if (camWidth <= 0 || camHeight <= 0 || cam.length != camWidth * camHeight) {
      throw ArgumentError(
        'cam has ${cam.length} values, expected $camWidth x $camHeight.',
      );
    }

    // 1. ReLU (NaN / infinities count as 0), then divide by the maximum.
    final norm = Float64List(cam.length);
    var maxValue = 0.0;
    for (var i = 0; i < cam.length; i++) {
      final v = cam[i];
      final r = (v.isFinite && v > 0) ? v : 0.0;
      norm[i] = r;
      if (r > maxValue) maxValue = r;
    }
    if (maxValue < flatEpsilon) return ScanTrace.empty();
    for (var i = 0; i < norm.length; i++) {
      norm[i] /= maxValue;
    }

    // 2. Bilinear-upsample onto the full image grid via the preprocessing map.
    final heat = Uint8List(resolution * resolution);
    var seen = 0;
    var covered = 0;
    var any = false;
    for (var row = 0; row < resolution; row++) {
      final y = (row + 0.5) / resolution;
      for (var col = 0; col < resolution; col++) {
        final x = (col + 0.5) / resolution;
        final p = mapping.imageToInput(x, y);
        if (p == null) continue;
        seen++;
        final v = _bilinear(norm, camWidth, camHeight, p.u, p.v);
        if (v >= coverageLevel) covered++;
        final b = (v * 255).round().clamp(0, 255);
        if (b > 0) any = true;
        heat[row * resolution + col] = b;
      }
    }

    final coverage = seen == 0 ? 0.0 : covered / seen;
    return ScanTrace(
      heat: heat,
      coverage: coverage,
      diffuse: !any || coverage > diffuseCoverage,
    );
  }

  static double _bilinear(Float64List g, int w, int h, double u, double v) {
    final fx = _clamp(u * w - 0.5, 0, w - 1.0);
    final fy = _clamp(v * h - 0.5, 0, h - 1.0);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1 < w ? x0 + 1 : x0;
    final y1 = y0 + 1 < h ? y0 + 1 : y0;
    final tx = fx - x0;
    final ty = fy - y0;
    final top = g[y0 * w + x0] * (1 - tx) + g[y0 * w + x1] * tx;
    final bottom = g[y1 * w + x0] * (1 - tx) + g[y1 * w + x1] * tx;
    return top * (1 - ty) + bottom * ty;
  }

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}
