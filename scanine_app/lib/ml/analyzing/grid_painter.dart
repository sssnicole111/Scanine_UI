// lib/ml/analyzing/grid_painter.dart
// Verbatim from scanine_analyzing.zip — imports adapted.
import 'package:flutter/material.dart';

import 'analyze_clock.dart';
import 'analyzing_tokens.dart';

/// Layers 1 and 2: the navy scrim and the lattice with its centre axes.
class GridPainter extends CustomPainter {
  GridPainter({required this.clock, required this.tokens})
    : super(repaint: clock.repaint);

  final AnalyzeClock clock;
  final AnalyzingTokens tokens;

  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _axis = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  Size? _pathSize;
  int? _pathRows;
  Path _lines = Path();
  Path _axes = Path();

  void _ensurePaths(Size size) {
    if (_pathSize == size && _pathRows == clock.rows) return;
    _pathSize = size;
    _pathRows = clock.rows;
    final cols = clock.columns;
    final rows = clock.rows;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final lines = Path();
    for (var i = 1; i < cols; i++) {
      if (i * 2 == cols) continue;
      final x = i * cw;
      lines
        ..moveTo(x, 0)
        ..lineTo(x, size.height);
    }
    for (var j = 1; j < rows; j++) {
      if (j * 2 == rows) continue;
      final y = j * ch;
      lines
        ..moveTo(0, y)
        ..lineTo(size.width, y);
    }
    _lines = lines;
    _axes = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2, size.height)
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    clock.guard(() {
      final f = clock.frame();
      final rect = Offset.zero & size;

      final scrimK =
          f.scrim * (1 - f.handoff * (1 - clock.config.resultScrimFactor));
      if (scrimK > 0) {
        _fill.color = withOpacityF(
          tokens.stageScrim,
          tokens.stageScrimOpacity * scrimK,
        );
        canvas.drawRect(rect, _fill);
      }

      if (f.gridAlpha <= 0 || f.gridDraw <= 0) return;
      _ensurePaths(size);
      final e = 1 - (1 - f.gridDraw) * (1 - f.gridDraw) * (1 - f.gridDraw);
      canvas.save();
      canvas.clipRect(
        Rect.fromCenter(
          center: rect.center,
          width: size.width * e,
          height: size.height * e,
        ),
      );
      _line.color = withOpacityF(
        tokens.gridLine,
        tokens.gridLineOpacity * f.gridAlpha,
      );
      _axis.color = withOpacityF(
        tokens.gridAxis,
        tokens.gridAxisOpacity * f.gridAlpha,
      );
      canvas.drawPath(_lines, _line);
      canvas.drawPath(_axes, _axis);
      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.clock != clock || old.tokens != tokens;
}
