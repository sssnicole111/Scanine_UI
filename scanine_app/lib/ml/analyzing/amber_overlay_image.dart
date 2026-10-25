// lib/ml/analyzing/amber_overlay_image.dart
//
// Builds a small (112×112) ui.Image from a ScanTrace for use on the
// Analyzing screen's dim + amber tint effect.
//
// The image is RGBA where:
//   R = G = B = 255 (white — any colour is applied in the painter)
//   A = heat byte (0..255) — used as the mask intensity
//
// The painter scales this image over the photo with bilinear filtering.
// Using a pre-built image instead of per-pixel paint calls keeps the
// CustomPainter GPU-friendly and avoids allocations per frame.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'scan_trace.dart';

abstract final class AmberOverlayImage {
  /// Side of the image we generate. 112 is 2× the 56×56 trace and still
  /// tiny enough that decoding and GPU upload are near-instant.
  static const int side = 112;

  /// Builds a [ui.Image] where alpha encodes heat intensity (0..255).
  /// RGB is always 255 so the painter can tint with [BlendMode.modulate].
  static Future<ui.Image> fromTrace(ScanTrace trace) {
    const n = ScanTrace.resolution; // 56
    const out = side; // 112
    final px = Uint8List(out * out * 4);

    for (var row = 0; row < out; row++) {
      // Map output row to trace row via nearest-bilinear sample.
      final fy = (row + 0.5) / out * n - 0.5;
      final y0 = fy.floor().clamp(0, n - 1);
      final y1 = (y0 + 1).clamp(0, n - 1);
      final ty = fy - y0;

      for (var col = 0; col < out; col++) {
        final fx = (col + 0.5) / out * n - 0.5;
        final x0 = fx.floor().clamp(0, n - 1);
        final x1 = (x0 + 1).clamp(0, n - 1);
        final tx = fx - x0;

        // Bilinear interpolation of the 56×56 heat.
        final h00 = trace.heat[y0 * n + x0];
        final h01 = trace.heat[y0 * n + x1];
        final h10 = trace.heat[y1 * n + x0];
        final h11 = trace.heat[y1 * n + x1];
        final top = h00 + (h01 - h00) * tx;
        final bot = h10 + (h11 - h10) * tx;
        final v = (top + (bot - top) * ty).clamp(0.0, 255.0).round();

        final base = (row * out + col) * 4;
        px[base] = 255; // R
        px[base + 1] = 255; // G
        px[base + 2] = 255; // B
        px[base + 3] = v; // A = heat
      }
    }

    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, out, out, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}
