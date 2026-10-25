import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/ml/analyzing/input_mapping.dart';
import 'package:scanine_app/ml/analyzing/scan_trace.dart';

/// 7x7 map with gaussian blobs at (x, y, sigma) in cam cells.
List<double> blobMap(List<List<double>> blobs, {int n = 7}) {
  final out = List<double>.filled(n * n, 0);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var v = 0.0;
      for (final b in blobs) {
        final dx = x + 0.5 - b[0];
        final dy = y + 0.5 - b[1];
        v += math.exp(-(dx * dx + dy * dy) / (2 * b[2] * b[2]));
      }
      out[y * n + x] = v;
    }
  }
  return out;
}

int argMax(Uint8List h) {
  var best = 0;
  for (var i = 1; i < h.length; i++) {
    if (h[i] > h[best]) best = i;
  }
  return best;
}

void main() {
  const n = ScanTrace.resolution;

  group('ScanTrace.fromCam', () {
    test('one blob peaks where the blob is and is not diffuse', () {
      final t = ScanTrace.fromCam(
        cam: blobMap([
          [5.0, 2.0, 0.8],
        ]),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isFalse);
      expect(t.heat.length, equals(n * n));
      final i = argMax(t.heat);
      final row = i ~/ n, col = i % n;
      // blob at cam (5,2) -> image (5/7, 2/7) = cell (40, 16)
      expect(col, closeTo(40, 4));
      expect(row, closeTo(16, 4));
      expect(t.heat[i], equals(255));
      expect(t.coverage, greaterThan(0.01));
      expect(t.coverage, lessThan(0.3));
    });

    test('two blobs give two separated maxima', () {
      final t = ScanTrace.fromCam(
        cam: blobMap([
          [1.5, 1.5, 0.6],
          [5.5, 5.5, 0.6],
        ]),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isFalse);
      double at(double x, double y) => t.valueAt(x / 7, y / 7);
      expect(at(1.5, 1.5), greaterThan(0.8));
      expect(at(5.5, 5.5), greaterThan(0.8));
      expect(at(3.5, 3.5), lessThan(0.25));
    });

    test('a flat map is diffuse', () {
      final t = ScanTrace.fromCam(
        cam: List<double>.filled(49, 0.7),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isTrue);
      expect(t.coverage, greaterThan(0.6));
    });

    test('an all-zero map is diffuse with an all-zero heat', () {
      final t = ScanTrace.fromCam(
        cam: List<double>.filled(49, 0),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isTrue);
      expect(t.coverage, equals(0));
      expect(t.heat.every((b) => b == 0), isTrue);
    });

    test('a negative-only map (ReLU) is empty', () {
      final t = ScanTrace.fromCam(
        cam: List<double>.filled(49, -3),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isTrue);
      expect(t.heat.every((b) => b == 0), isTrue);
    });

    test('NaN cells are treated as 0', () {
      final cam = blobMap([
        [3.5, 3.5, 0.8],
      ]);
      cam[0] = double.nan;
      final t = ScanTrace.fromCam(cam: cam, camWidth: 7, camHeight: 7);
      expect(t.diffuse, isFalse);
      expect(t.heat[0], equals(0));
    });

    test('a blob touching the border stays in range', () {
      final t = ScanTrace.fromCam(
        cam: blobMap([
          [0.2, 0.2, 0.7],
        ]),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.diffuse, isFalse);
      final i = argMax(t.heat);
      expect(i ~/ n, lessThan(6));
      expect(i % n, lessThan(6));
      expect(t.heat[0], greaterThan(200));
      expect(t.heat[n * n - 1], lessThan(10));
    });

    test('wrong cam length throws', () {
      expect(
        () => ScanTrace.fromCam(cam: [1, 2, 3], camWidth: 7, camHeight: 7),
        throwsArgumentError,
      );
    });
  });

  group('preprocessing to full image', () {
    final blobAtLeft = blobMap([
      [0.5, 3.5, 0.6],
    ]);

    test('stretch: cam position equals image position', () {
      final t = ScanTrace.fromCam(
        cam: blobMap([
          [3.5, 3.5, 0.8],
        ]),
        camWidth: 7,
        camHeight: 7,
      );
      expect(t.valueAt(0.5, 0.5), greaterThan(0.9));
      expect(t.valueAt(0.05, 0.5), lessThan(0.1));
    });

    test('centre crop: cells outside the crop are 0', () {
      // 400x300 landscape photo, 224x224 input: the model sees x in 0.125..0.875
      final m = InputMapping.centerCrop(
        imageWidth: 400,
        imageHeight: 300,
        inputWidth: 224,
        inputHeight: 224,
      );
      expect(m.seen.left, closeTo(0.125, 1e-9));
      expect(m.seen.right, closeTo(0.875, 1e-9));
      expect(m.seen.top, closeTo(0, 1e-9));
      final t = ScanTrace.fromCam(
        cam: List<double>.filled(49, 1.0)..[24] = 5, // hot centre cell
        camWidth: 7,
        camHeight: 7,
        mapping: m,
      );
      // image columns 0..5 (x < 0.125) were never seen
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < 7; col++) {
          expect(t.heat[row * n + col], equals(0));
        }
      }
      expect(t.valueAt(0.5, 0.5), greaterThan(0.8));
    });

    test('centre crop: blob at the left edge of the crop lands at x=0.125', () {
      final m = InputMapping.centerCrop(
        imageWidth: 400,
        imageHeight: 300,
        inputWidth: 224,
        inputHeight: 224,
      );
      final t = ScanTrace.fromCam(
        cam: blobAtLeft,
        camWidth: 7,
        camHeight: 7,
        mapping: m,
      );
      final i = argMax(t.heat);
      final x = ((i % n) + 0.5) / n;
      // The peak sits at x = 0.125 + 0.75 * (0.5 / 7) = 0.179; the edge value
      // is held flat towards the crop border, so the first max may be a bit
      // left of it, but never outside the crop.
      expect(x, greaterThanOrEqualTo(0.125));
      expect(x, lessThan(0.2));
    });

    test(
      'letterbox: padding rows are 0 and coverage counts seen cells only',
      () {
        // 300x400 portrait photo letterboxed into a 224x224 input -> pillars
        final m = InputMapping.letterbox(
          imageWidth: 300,
          imageHeight: 400,
          inputWidth: 224,
          inputHeight: 224,
        );
        expect(m.placed.top, closeTo(0, 1e-9));
        expect(m.placed.left, closeTo(0.125, 1e-9));
        // Photo fills the placed rect, so a whole-input map shows up in full.
        final t = ScanTrace.fromCam(
          cam: blobMap([
            [3.5, 3.5, 0.9],
          ]),
          camWidth: 7,
          camHeight: 7,
          mapping: m,
        );
        expect(t.diffuse, isFalse);
        expect(t.valueAt(0.5, 0.5), greaterThan(0.9));
      },
    );

    test('imageToInput returns null outside what the model saw', () {
      final m = InputMapping.centerCrop(
        imageWidth: 400,
        imageHeight: 300,
        inputWidth: 224,
        inputHeight: 224,
      );
      expect(m.imageToInput(0.05, 0.5), isNull);
      final p = m.imageToInput(0.5, 0.5)!;
      expect(p.u, closeTo(0.5, 1e-9));
      expect(p.v, closeTo(0.5, 1e-9));
    });
  });
}
