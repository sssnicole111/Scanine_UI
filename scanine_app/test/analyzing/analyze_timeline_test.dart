import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/ml/analyzing/analyze_timeline.dart';

double v(double seconds) => seconds / AnalyzeTimeline.referenceSeconds;

void main() {
  group('CubicBezierEase', () {
    test('endpoints and monotonic', () {
      const e = AnalyzeTimeline.scanEase;
      expect(e.transform(0), equals(0));
      expect(e.transform(1), equals(1));
      var last = -1.0;
      for (var i = 0; i <= 100; i++) {
        final y = e.transform(i / 100);
        expect(y, greaterThanOrEqualTo(last));
        last = y;
      }
    });
  });

  group('AnalyzeTimeline (normal)', () {
    test('starts bare: no scrim, no grid, no frame, no scan', () {
      final f = AnalyzeTimeline.frameAt(0);
      expect(f.scrim, equals(0));
      expect(f.gridDraw, equals(0));
      expect(f.frameAlpha, equals(0));
      expect(f.scan, isNull);
    });

    test('scrim and grid are complete at 0.45 s, frame at 0.5 s', () {
      final f = AnalyzeTimeline.frameAt(v(0.45));
      expect(f.scrim, closeTo(1, 1e-9));
      expect(f.gridDraw, closeTo(1, 1e-9));
      expect(AnalyzeTimeline.frameAt(v(0.5)).frameAlpha, closeTo(1, 1e-9));
      expect(AnalyzeTimeline.frameAt(v(0.1)).frameAlpha, closeTo(0, 1e-9));
    });

    test('scan line sweeps top to bottom between 0.5 s and 1.7 s only', () {
      expect(AnalyzeTimeline.frameAt(v(0.49)).scan, isNull);
      expect(AnalyzeTimeline.frameAt(v(1.71)).scan, isNull);
      var last = -1.0;
      for (var t = 0.51; t < 1.69; t += 0.02) {
        final s = AnalyzeTimeline.frameAt(v(t)).scan!;
        expect(s, greaterThanOrEqualTo(last));
        last = s;
      }
      expect(AnalyzeTimeline.frameAt(v(0.52)).scan!, lessThan(0.05));
      expect(AnalyzeTimeline.frameAt(v(1.68)).scan!, greaterThan(0.95));
    });

    test('cells appear row by row as the line passes', () {
      final mid = AnalyzeTimeline.frameAt(v(1.1));
      final line = mid.scan!;
      expect(mid.cellAlpha(line - 0.2), equals(1));
      expect(mid.cellAlpha(line + 0.2), equals(0));
    });

    test('hold: every cell fully visible, grid still there', () {
      final f = AnalyzeTimeline.frameAt(v(2.0));
      expect(f.cellAlpha(0.99), equals(1));
      expect(f.cellAlpha(0.01), equals(1));
      expect(f.gridAlpha, equals(1));
      expect(f.smoothAlpha, equals(0));
      expect(f.scan, isNull);
    });

    test(
      'hand-off: grid and cells fade, smooth overlay arrives, frame stays',
      () {
        final end = AnalyzeTimeline.frameAt(1);
        expect(end.gridAlpha, closeTo(0, 1e-9));
        expect(end.cellsAlpha, closeTo(0, 1e-9));
        expect(end.smoothAlpha, closeTo(1, 1e-9));
        expect(end.frameAlpha, equals(1));
        final start = AnalyzeTimeline.frameAt(v(2.4));
        expect(start.handoff, closeTo(0, 1e-9));
      },
    );

    test('nothing flashes: opacity never jumps between close frames', () {
      var last = AnalyzeTimeline.frameAt(0);
      for (var i = 1; i <= 600; i++) {
        final f = AnalyzeTimeline.frameAt(i / 600);
        expect((f.scrim - last.scrim).abs(), lessThan(0.05));
        expect((f.gridAlpha - last.gridAlpha).abs(), lessThan(0.05));
        expect((f.cellsAlpha - last.cellsAlpha).abs(), lessThan(0.05));
        expect((f.frameAlpha - last.frameAlpha).abs(), lessThan(0.05));
        last = f;
      }
    });
  });

  group('modes', () {
    test(
      'reduced motion: no scan line, cross-fade to the final composition',
      () {
        for (var i = 0; i <= 20; i++) {
          expect(
            AnalyzeTimeline.frameAt(i / 20, mode: AnalyzeMode.reduced).scan,
            isNull,
          );
        }
        final end = AnalyzeTimeline.frameAt(1, mode: AnalyzeMode.reduced);
        expect(end.gridAlpha, equals(1));
        expect(end.cellAlpha(0.9), equals(1));
        expect(end.frameAlpha, equals(1));
        final mid = AnalyzeTimeline.frameAt(0.25, mode: AnalyzeMode.reduced);
        expect(mid.frameAlpha, closeTo(0.5, 1e-9));
      },
    );

    test('low end: cells fade in as one group, no stagger', () {
      final f = AnalyzeTimeline.frameAt(v(1.0), mode: AnalyzeMode.lowEnd);
      expect(f.staggered, isFalse);
      expect(f.cellAlpha(0.1), equals(f.cellAlpha(0.9)));
      expect(
        AnalyzeTimeline.frameAt(
          v(2.0),
          mode: AnalyzeMode.lowEnd,
        ).cellAlpha(0.5),
        equals(1),
      );
    });

    test('waiting for the trace: scan loops, no cell is lit', () {
      for (var i = 1; i < 20; i++) {
        final f = AnalyzeTimeline.frameAt(
          AnalyzeTimeline.introEnd,
          waitLoop: i / 20,
        );
        expect(f.scan, isNotNull);
        expect(f.cellAlpha(0.5), equals(0));
        expect(f.frameAlpha, equals(1));
        expect(f.gridAlpha, equals(1));
      }
    });
  });

  test('constants', () {
    expect(kMinAnalyzeMs, equals(3000));
    expect(AnalyzeTimeline.introEnd, closeTo(0.5 / 3.0, 1e-12));
  });
}
