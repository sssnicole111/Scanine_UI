// lib/ml/gradcam_contours.dart
//
// Converts a raw Grad-CAM Float32List into a list of axis-aligned bounding
// rects (normalised 0..1 in image-space) that surround each connected region
// of high activation.
//
// All work is done once, synchronously, before the animation starts.
// Nothing in this file touches Flutter widgets — it is pure Dart so it can
// be run in a compute() isolate if needed.

import 'dart:math' as math;
import 'dart:typed_data';

/// A normalised bounding rect of one high-activation region.
/// All values are in [0, 1] relative to the original image dimensions.
class CamRegion {
  const CamRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.peakActivation,
  });

  final double left, top, right, bottom;

  /// The highest CAM value (0..1) inside this region. Used to tint the glow.
  final double peakActivation;

  double get width => right - left;
  double get height => bottom - top;
  double get cx => (left + right) / 2;
  double get cy => (top + bottom) / 2;

  /// Vertical midpoint in normalised image space.
  /// The scan-line uses this to decide when to reveal the region.
  double get scanMid => (top + bottom) / 2;

  /// Convert to pixel coordinates within the displayed photo size.
  /// Returns (pixelLeft, pixelTop, pixelRight, pixelBottom).
  (double, double, double, double) toPixels(double displayW, double displayH) =>
      (left * displayW, top * displayH, right * displayW, bottom * displayH);
}

/// Threshold the [cam] heatmap, flood-fill connected components, and return
/// one bounding [CamRegion] per component that is large enough to show.
///
/// Parameters
/// ----------
/// cam        – normalised Grad-CAM values (already 0..1), row-major.
///              This is [FrameResult.cam] — already normalised by the
///              classifier's _gradCam().
/// camH, camW – grid dimensions (typically 7×7 from MobileNetV3-Small's last conv).
/// threshold  – cells with activation >= threshold are treated as active.
///              0.40 is a reasonable starting point for the already-normalised
///              cam; the heatmap.dart renderer uses 0.18 on the same data
///              (same threshold, different visual purpose).
/// minRegionFraction – components smaller than this fraction of total cells
///              are dropped as noise (e.g. 0.03 = at least 1.5 of 49 cells).
///
/// Returns an empty list when no region survives the filters.
/// The caller MUST fall back to a plain full-image scan in that case.
List<CamRegion> extractCamRegions(
  Float32List cam, {
  required int camH,
  required int camW,
  double threshold = 0.40,
  double minRegionFraction = 0.03,
}) {
  assert(cam.length == camH * camW,
      'cam length ${cam.length} != $camH * $camW = ${camH * camW}');

  // ── 1. Binary mask ────────────────────────────────────────────────────────
  final mask = List<bool>.filled(camH * camW, false);
  for (var i = 0; i < cam.length; i++) {
    mask[i] = cam[i] >= threshold;
  }

  // ── 2. 4-connected flood-fill labelling ───────────────────────────────────
  final labels = List<int>.filled(camH * camW, -1); // -1 = unlabelled
  var nextLabel = 0;

  // Per-label stats collected during the fill.
  final bboxes = <int, List<double>>{}; // label -> [minX, minY, maxX, maxY]
  final peaks = <int, double>{};
  final sizes = <int, int>{};

  void flood(int seedY, int seedX, int label) {
    // Iterative BFS — no recursion so we never blow the stack.
    final queue = <(int, int)>[(seedY, seedX)];
    var head = 0;
    while (head < queue.length) {
      final (y, x) = queue[head++];
      if (y < 0 || y >= camH || x < 0 || x >= camW) continue;
      final idx = y * camW + x;
      if (labels[idx] >= 0 || !mask[idx]) continue;

      labels[idx] = label;
      sizes[label] = (sizes[label] ?? 0) + 1;

      final v = cam[idx];
      if (v > (peaks[label] ?? 0.0)) peaks[label] = v;

      final box = bboxes[label];
      if (box == null) {
        bboxes[label] = [
          x.toDouble(),
          y.toDouble(),
          x.toDouble(),
          y.toDouble()
        ];
      } else {
        if (x < box[0]) box[0] = x.toDouble();
        if (y < box[1]) box[1] = y.toDouble();
        if (x > box[2]) box[2] = x.toDouble();
        if (y > box[3]) box[3] = y.toDouble();
      }

      // 4-connected neighbours
      if (x + 1 < camW && labels[idx + 1] < 0 && mask[idx + 1]) {
        queue.add((y, x + 1));
      }
      if (x - 1 >= 0 && labels[idx - 1] < 0 && mask[idx - 1]) {
        queue.add((y, x - 1));
      }
      if (y + 1 < camH && labels[idx + camW] < 0 && mask[idx + camW]) {
        queue.add((y + 1, x));
      }
      if (y - 1 >= 0 && labels[idx - camW] < 0 && mask[idx - camW]) {
        queue.add((y - 1, x));
      }
    }
  }

  for (var y = 0; y < camH; y++) {
    for (var x = 0; x < camW; x++) {
      final idx = y * camW + x;
      if (mask[idx] && labels[idx] < 0) {
        flood(y, x, nextLabel++);
      }
    }
  }

  // ── 3. Filter noise ───────────────────────────────────────────────────────
  final minCells = math.max(1, (camH * camW * minRegionFraction).ceil());
  final regions = <CamRegion>[];

  for (var label = 0; label < nextLabel; label++) {
    if ((sizes[label] ?? 0) < minCells) continue;

    final box = bboxes[label]!;
    final peak = peaks[label] ?? 0.0;

    // ── 4. Grid coords → normalised image coords ──────────────────────────
    // Cell (cx, cy) runs from cx/camW to (cx+1)/camW in image space.
    // Add half-a-cell visual margin so the outline sits outside the hot
    // pixels rather than on their edge.
    const margin = 0.5;
    final left = math.max(0.0, (box[0] - margin) / camW);
    final top = math.max(0.0, (box[1] - margin) / camH);
    final right = math.min(1.0, (box[2] + 1.0 + margin) / camW);
    final bottom = math.min(1.0, (box[3] + 1.0 + margin) / camH);

    regions.add(CamRegion(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      peakActivation: peak,
    ));
  }

  // Sort top-to-bottom so the scan line discovers them in order.
  regions.sort((a, b) => a.scanMid.compareTo(b.scanMid));
  return regions;
}
