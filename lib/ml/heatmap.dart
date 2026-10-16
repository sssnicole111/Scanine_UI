import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Renders a Grad-CAM map over the photo it came from.
///
/// The CAM is 7x7 in the *square-resized* space the model saw, so it is
/// bilinearly stretched across the full frame — the inverse of the squash
/// applied during preprocessing, which keeps the overlay aligned with what
/// the model actually looked at.
Future<Uint8List?> renderHeatmap({
  required String photoPath,
  required Float32List cam,
  required int camH,
  required int camW,
  int maxWidth = 720,
  double threshold = 0.18,
  double maxAlpha = 0.62,
}) async {
  final decoded = img.decodeImage(await File(photoPath).readAsBytes());
  if (decoded == null) return null;

  final base = decoded.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth)
      : decoded;

  final w = base.width;
  final h = base.height;

  for (var y = 0; y < h; y++) {
    final fy = (y + 0.5) / h * (camH - 1);
    final y0 = fy.floor().clamp(0, camH - 1);
    final y1 = (y0 + 1).clamp(0, camH - 1);
    final wy = fy - y0;

    for (var x = 0; x < w; x++) {
      final fx = (x + 0.5) / w * (camW - 1);
      final x0 = fx.floor().clamp(0, camW - 1);
      final x1 = (x0 + 1).clamp(0, camW - 1);
      final wx = fx - x0;

      // bilinear interpolation of the coarse map
      final v00 = cam[y0 * camW + x0];
      final v01 = cam[y0 * camW + x1];
      final v10 = cam[y1 * camW + x0];
      final v11 = cam[y1 * camW + x1];
      final top = v00 + (v01 - v00) * wx;
      final bot = v10 + (v11 - v10) * wx;
      final v = (top + (bot - top) * wy).clamp(0.0, 1.0);

      if (v <= threshold) continue;

      // ramp alpha in from the threshold so edges aren't hard
      final t = (v - threshold) / (1.0 - threshold);
      final alpha = maxAlpha * t;

      final c = _jet(v);
      final px = base.getPixel(x, y);
      base.setPixelRgb(
        x,
        y,
        (px.r * (1 - alpha) + c[0] * alpha).round().clamp(0, 255),
        (px.g * (1 - alpha) + c[1] * alpha).round().clamp(0, 255),
        (px.b * (1 - alpha) + c[2] * alpha).round().clamp(0, 255),
      );
    }
  }

  return Uint8List.fromList(img.encodePng(base));
}

/// Classic "jet" ramp — blue (low) through green to red (high). Chosen
/// deliberately: it is what Grad-CAM figures look like in the literature,
/// so the overlay reads as the standard thing rather than a custom one.
List<int> _jet(double v) {
  double band(double centre) => (1.5 - (4 * v - centre).abs()).clamp(0.0, 1.0);
  return [
    (band(3) * 255).round(),
    (band(2) * 255).round(),
    (band(1) * 255).round(),
  ];
}
