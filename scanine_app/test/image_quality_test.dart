import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/ml/image_quality.dart';

/// A [w] x [h] RGBA image filled by [lum] (0-255 grey).
Uint8List _grey(int w, int h, int Function(int x, int y) lum) {
  final b = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = lum(x, y);
      final i = (y * w + x) * 4;
      b[i] = v;
      b[i + 1] = v;
      b[i + 2] = v;
      b[i + 3] = 255;
    }
  }
  return b;
}

void main() {
  test('textured frame is sharp, blank frame is blurry', () {
    final texture = _grey(1280, 720, (x, y) => ((x ~/ 6 + y ~/ 6).isEven) ? 70 : 170);
    final blank = _grey(1280, 720, (x, y) => 120);
    expect(QualityGate.assessRgba(texture, 1280, 720).focus, FocusStatus.sharp);
    expect(QualityGate.assessRgba(blank, 1280, 720).focus, FocusStatus.blurry);
  });

  test('rejudge applies a stricter, scene-relative limit', () {
    final texture = _grey(1280, 720, (x, y) => ((x ~/ 6 + y ~/ 6).isEven) ? 70 : 170);
    final a = QualityGate.assessRgba(texture, 1280, 720);
    expect(QualityGate.rejudge(a, blurMin: a.blurScore * 0.5).isAcceptable, isTrue);
    final b = QualityGate.rejudge(a, blurMin: a.blurScore * 2);
    expect(b.focus, FocusStatus.blurry);
    expect(b.isAcceptable, isFalse);
  });
}
