// lib/ml/analyzing/heat_grid.dart
// Verbatim from scanine_analyzing.zip.
import 'dart:math' as math;

import 'scan_trace.dart';

/// One lit grid cell.
class LitCell {
  const LitCell({
    required this.row,
    required this.col,
    required this.alpha,
    required this.rowProgress,
  });

  final int row;
  final int col;

  /// Final opacity of the cell: heat x [HeatGrid.maxCellAlpha].
  final double alpha;

  /// Where the scan line has to be (0..1 down the photo) for this cell to
  /// appear: the vertical centre of its row.
  final double rowProgress;
}

/// The scan grid laid over the photo: 14 columns, square-ish cells.
class HeatGrid {
  HeatGrid._(this.columns, this.rows, this.lit);

  static const int defaultColumns = 14;

  /// A cell is lit from this fraction of the maximum heat.
  static const double litThreshold = 0.18;

  /// Opacity of a fully hot cell (alpha = value x this).
  static const double maxCellAlpha = 0.66;

  final int columns;
  final int rows;
  final List<LitCell> lit;

  /// Number of rows for a photo whose height / width ratio is [aspect].
  static int rowsFor(double aspect, {int columns = defaultColumns}) =>
      math.max(1, (aspect * columns).round());

  /// Samples [trace] at the centre of every cell.
  factory HeatGrid.fromTrace(
    ScanTrace trace, {
    required double aspect,
    int columns = defaultColumns,
  }) {
    final rows = rowsFor(aspect, columns: columns);
    final lit = <LitCell>[];
    if (!trace.diffuse) {
      for (var r = 0; r < rows; r++) {
        final y = (r + 0.5) / rows;
        for (var c = 0; c < columns; c++) {
          final x = (c + 0.5) / columns;
          final v = trace.valueAt(x, y);
          if (v < litThreshold) continue;
          lit.add(
            LitCell(
              row: r,
              col: c,
              alpha: math.min(v, 1.0) * maxCellAlpha,
              rowProgress: y,
            ),
          );
        }
      }
    }
    return HeatGrid._(columns, rows, List.unmodifiable(lit));
  }
}
