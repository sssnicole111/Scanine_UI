import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/ml/analyzing/heat_grid.dart';
import 'package:scanine_app/ml/analyzing/scan_trace.dart';

import 'fixture_cams.dart';

ScanTrace traceFor(String fixture) => ScanTrace.fromCam(
  cam: FixtureCams.cam(fixture),
  camWidth: FixtureCams.size,
  camHeight: FixtureCams.size,
);

/// Local maxima of the 56x56 heat that stand clearly above the rest.
int peaks(ScanTrace t) {
  const n = ScanTrace.resolution;
  var count = 0;
  for (var r = 2; r < n - 2; r++) {
    for (var c = 2; c < n - 2; c++) {
      final v = t.heat[r * n + c];
      if (v < 150) continue;
      var isMax = true;
      for (var dr = -2; dr <= 2 && isMax; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          if (dr == 0 && dc == 0) continue;
          final o = t.heat[(r + dr) * n + c + dc];
          if (o > v || (o == v && (dr < 0 || (dr == 0 && dc < 0)))) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax) count++;
    }
  }
  return count;
}

void main() {
  group('HeatGrid', () {
    test('rows follow the photo height (4:3 portrait -> 14 x 19)', () {
      expect(HeatGrid.rowsFor(4 / 3), equals(19));
      expect(HeatGrid.rowsFor(1), equals(14));
      expect(HeatGrid.rowsFor(0.01), equals(1));
    });

    test('one cluster has one peak and lights cells', () {
      final t = traceFor(FixtureCams.oneCluster);
      expect(peaks(t), equals(1));
      expect(HeatGrid.fromTrace(t, aspect: 4 / 3).lit, isNotEmpty);
    });

    test('several clusters have several peaks and light more cells', () {
      final one = HeatGrid.fromTrace(
        traceFor(FixtureCams.oneCluster),
        aspect: 4 / 3,
      );
      final t = traceFor(FixtureCams.severalClusters);
      expect(peaks(t), greaterThanOrEqualTo(3));
      expect(
        HeatGrid.fromTrace(t, aspect: 4 / 3).lit.length,
        greaterThan(one.lit.length),
      );
    });

    test('lit cells sit on the heat, not on fixed positions', () {
      final t = traceFor(FixtureCams.severalClusters);
      final g = HeatGrid.fromTrace(t, aspect: 4 / 3);
      for (final c in g.lit) {
        final v = t.valueAt((c.col + 0.5) / g.columns, (c.row + 0.5) / g.rows);
        expect(v, greaterThanOrEqualTo(HeatGrid.litThreshold));
      }
      // and an unlit cell is below the threshold
      final lit = {for (final c in g.lit) c.row * g.columns + c.col};
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.columns; c++) {
          if (lit.contains(r * g.columns + c)) continue;
          expect(
            t.valueAt((c + 0.5) / g.columns, (r + 0.5) / g.rows),
            lessThan(HeatGrid.litThreshold),
          );
        }
      }
    });

    test('different fixtures give different patterns', () {
      String key(String f) => (HeatGrid.fromTrace(
        traceFor(f),
        aspect: 4 / 3,
      ).lit.map((c) => '${c.row},${c.col}').toList()..sort()).join('|');
      expect(
        key(FixtureCams.oneCluster),
        isNot(equals(key(FixtureCams.severalClusters))),
      );
    });

    test('diffuse and empty fixtures light no cells', () {
      for (final f in [FixtureCams.diffuse, FixtureCams.empty]) {
        final t = traceFor(f);
        expect(t.diffuse, isTrue);
        expect(HeatGrid.fromTrace(t, aspect: 4 / 3).lit, isEmpty);
      }
    });

    test('lit cells respect the threshold and the alpha cap', () {
      final g = HeatGrid.fromTrace(
        traceFor(FixtureCams.severalClusters),
        aspect: 4 / 3,
      );
      for (final c in g.lit) {
        expect(
          c.alpha,
          greaterThanOrEqualTo(HeatGrid.litThreshold * 0.66 - 1e-9),
        );
        expect(c.alpha, lessThanOrEqualTo(HeatGrid.maxCellAlpha + 1e-9));
        expect(c.rowProgress, greaterThan(0));
        expect(c.rowProgress, lessThan(1));
      }
    });

    test('stays within the cell budget (about 280 rects per frame)', () {
      final g = HeatGrid.fromTrace(
        traceFor(FixtureCams.severalClusters),
        aspect: 4 / 3,
      );
      expect(g.lit.length, lessThanOrEqualTo(g.columns * g.rows));
      expect(g.columns * g.rows, lessThanOrEqualTo(280));
    });
  });
}
