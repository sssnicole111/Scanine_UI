// lib/ml/analyzing/heat_overlay_image.dart
// Verbatim from scanine_analyzing.zip — imports adapted.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'scan_trace.dart';

/// The 56x56 heat as a small image: cloud-white, alpha = heat.
/// Drawn stretched over the photo with bilinear filtering.
abstract final class HeatOverlayImage {
  static Future<ui.Image> fromTrace(
    ScanTrace trace, {
    int r = 0xF4,
    int g = 0xF5,
    int b = 0xFA,
  }) {
    const n = ScanTrace.resolution;
    final px = Uint8List(n * n * 4);
    for (var i = 0; i < n * n; i++) {
      final a = trace.heat[i];
      px[i * 4] = (r * a / 255).round();
      px[i * 4 + 1] = (g * a / 255).round();
      px[i * 4 + 2] = (b * a / 255).round();
      px[i * 4 + 3] = a;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}
