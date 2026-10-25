import 'dart:math' as math;

/// Raw 7x7 Grad-CAM maps for tests and fixtures.
abstract final class FixtureCams {
  static const int size = 7;

  static const String oneCluster = 'One cluster';
  static const String severalClusters = 'Several clusters';
  static const String diffuse = 'Diffuse';
  static const String empty = 'Empty';

  static const List<String> names = [
    oneCluster,
    severalClusters,
    diffuse,
    empty,
  ];

  /// Gaussian blobs as (centreX, centreY, sigma, amplitude) in cam cells.
  static const Map<String, List<List<double>>> blobs = {
    oneCluster: [
      [3.4, 3.1, 0.95, 1.0],
    ],
    severalClusters: [
      [2.2, 1.9, 0.75, 1.0],
      [4.9, 3.7, 0.66, 0.92],
      [2.5, 5.3, 0.62, 0.86],
    ],
  };

  static List<double> cam(String name) {
    final out = List<double>.filled(size * size, 0);
    switch (name) {
      case diffuse:
        // Flat-ish map with weak noise: nothing stands out.
        final rnd = math.Random(7);
        for (var i = 0; i < out.length; i++) {
          out[i] = 0.62 + 0.10 * rnd.nextDouble();
        }
      case empty:
        break; // all zeros
      default:
        final spec = blobs[name] ?? blobs[oneCluster]!;
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            var v = 0.03;
            for (final b in spec) {
              final dx = x + 0.5 - b[0];
              final dy = y + 0.5 - b[1];
              v += b[3] * math.exp(-(dx * dx + dy * dy) / (2 * b[2] * b[2]));
            }
            out[y * size + x] = v;
          }
        }
    }
    return out;
  }
}
