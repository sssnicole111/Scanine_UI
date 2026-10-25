// lib/ml/analyzing/heat_scan_painter.dart
// Verbatim from scanine_analyzing.zip — imports adapted.
import 'package:flutter/material.dart';

import 'analyze_clock.dart';
import 'analyze_timeline.dart';
import 'analyzing_tokens.dart';

/// Layers 3 and 4: the lit heat cells and the scan line.
class HeatScanPainter extends CustomPainter {
  HeatScanPainter({required this.clock, required this.tokens})
    : super(repaint: clock.repaint);

  final AnalyzeClock clock;
  final AnalyzingTokens tokens;

  final Paint _cell = Paint();
  final Paint _glow = Paint();
  final Paint _core = Paint();
  final Paint _image = Paint()..filterQuality = FilterQuality.high;

  final MaskFilter _blur = const MaskFilter.blur(BlurStyle.normal, 8);

  @override
  void paint(Canvas canvas, Size size) {
    clock.guard(() {
      final f = clock.frame();
      canvas.save();
      canvas.clipRect(Offset.zero & size);

      final grid = clock.grid;
      if (grid != null && f.cellsAlpha > 0 && grid.lit.isNotEmpty) {
        final cw = size.width / grid.columns;
        final ch = size.height / grid.rows;
        for (final c in grid.lit) {
          final a = f.cellAlpha(c.rowProgress) * c.alpha * f.cellsAlpha;
          if (a < 0.004) continue;
          _cell.color = withOpacityF(tokens.cloud, a);
          canvas.drawRect(
            Rect.fromLTWH(c.col * cw + 0.5, c.row * ch + 0.5, cw - 1, ch - 1),
            _cell,
          );
        }
      }

      final overlay = clock.overlay;
      if (overlay != null && f.smoothAlpha > 0) {
        _image.color = withOpacityF(
          const Color(0xFFFFFFFF),
          clock.config.resultOverlayOpacity * f.smoothAlpha,
        );
        canvas.drawImageRect(
          overlay,
          Rect.fromLTWH(
            0,
            0,
            overlay.width.toDouble(),
            overlay.height.toDouble(),
          ),
          Offset.zero & size,
          _image,
        );
      }

      final scan = f.scan;
      if (scan != null && f.scanAlpha > 0) {
        final y = scan * size.height;
        final a = f.scanAlpha;
        if (clock.mode == AnalyzeMode.lowEnd) {
          _glow.maskFilter = null;
          _glow.color = withOpacityF(tokens.scanGrey, 0.10 * a);
          canvas.drawRect(Rect.fromLTWH(0, y - 12, size.width, 24), _glow);
          _glow.color = withOpacityF(tokens.scanGrey, 0.16 * a);
          canvas.drawRect(Rect.fromLTWH(0, y - 5, size.width, 10), _glow);
        } else {
          _glow.maskFilter = _blur;
          _glow.color = withOpacityF(tokens.scanGrey, 0.7 * a);
          canvas.drawRect(Rect.fromLTWH(0, y - 4, size.width, 8), _glow);
        }
        _core.color = withOpacityF(tokens.cloud, a);
        canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), _core);
      }

      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(HeatScanPainter old) =>
      old.clock != clock || old.tokens != tokens;
}
