import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Focus status determined by Laplacian variance.
enum FocusStatus {
  sharp,
  blurry,
  checking,
}

/// Light status determined by mean pixel intensity.
enum LightStatus {
  adequate,
  lowLight,
  tooDark,
  tooBright,
  checking,
}

/// Quality gate thresholds as specified in the Scanine research paper
/// (Chapter 3 & 4: Laplacian variance for blur and mean pixel intensity for exposure).
class QualityThresholds {
  const QualityThresholds({
    this.blurMinVariance = 10.0,
    this.lightMinIntensity = 42.0,
    this.lightMaxIntensity = 222.0,
  });

  /// Floor on the variance of the Laplacian (measured on the shrunk centre
  /// grid) below which a frame is 'Blurry' whatever the scene: smeared
  /// or blank. 2.0% of the dataset dog photos fall below it. The camera
  /// also compares each frame with the sharpest recent one of the same scene
  /// ([relativeSharpness]), which is what catches a dog that moved.
  final double blurMinVariance;

  /// Minimum mean pixel luminance (0..255) for adequate lighting.
  final double lightMinIntensity;

  /// Maximum mean pixel luminance (0..255) before an image is considered overexposed.
  final double lightMaxIntensity;
}

/// A frame is blurry if its score is under this share of the sharpest recent
/// frame of the same scene. Tested by smearing 300 dataset dog photos at
/// phone resolution: 0.25 passes 98% of sharp frames and 90% with slight
/// motion (about 2 px at the model's 224 px), and rejects 78% with clear
/// motion (3 px) and 97% with heavy motion (6 px).
const double relativeSharpness = 0.25;

/// Consolidated result of the on-device image quality gate.
class QualityAssessment {
  const QualityAssessment({
    required this.blurScore,
    required this.lightScore,
    required this.focus,
    required this.light,
    required this.isAcceptable,
    required this.feedbackMessage,
  });

  final double blurScore;
  final double lightScore;
  final FocusStatus focus;
  final LightStatus light;
  final bool isAcceptable;
  final String feedbackMessage;

  String get focusLabel {
    switch (focus) {
      case FocusStatus.sharp:
        return 'Sharp';
      case FocusStatus.blurry:
        return 'Blurry';
      case FocusStatus.checking:
        return 'Checking…';
    }
  }

  String get lightLabel {
    switch (light) {
      case LightStatus.adequate:
        return 'Adequate';
      case LightStatus.lowLight:
        return 'Low Light';
      case LightStatus.tooDark:
        return 'Too Dark';
      case LightStatus.tooBright:
        return 'Too Bright';
      case LightStatus.checking:
        return 'Checking…';
    }
  }

  bool get isFocusGood => focus == FocusStatus.sharp;
  bool get isLightGood => light == LightStatus.adequate;

  static const QualityAssessment checking = QualityAssessment(
    blurScore: 0,
    lightScore: 0,
    focus: FocusStatus.checking,
    light: LightStatus.checking,
    isAcceptable: false,
    feedbackMessage: 'Keep the phone still over the affected area.',
  );
}

/// Quality gate implementation executing real-time Laplacian variance (blur)
/// and Mean Pixel Intensity (lighting) assessments.
class QualityGate {
  static const QualityThresholds defaultThresholds = QualityThresholds();

  /// Assesses a captured image file from disk.
  ///
  /// Decodes with the platform's own image decoder (fast, and off the UI
  /// thread), then measures the same centre patch as [assessDecodedImage].
  static Future<QualityAssessment> assessFile(
    String filePath, {
    QualityThresholds thresholds = defaultThresholds,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return QualityAssessment.checking;
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data == null) {
          return QualityAssessment.checking;
        }
        return assessRgba(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          image.width,
          image.height,
          thresholds: thresholds,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      return QualityAssessment.checking;
    }
  }

  /// Assesses raw RGBA pixels ([width] x [height], 4 bytes per pixel).
  static QualityAssessment assessRgba(
    Uint8List rgba,
    int width,
    int height, {
    QualityThresholds thresholds = defaultThresholds,
  }) {
    return _assessLuma(width, height, thresholds, (x, y) {
      final i = (y * width + x) * 4;
      return 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
    });
  }

  /// Assesses an [img.Image] decoded in memory.
  static QualityAssessment assessDecodedImage(
    img.Image image, {
    QualityThresholds thresholds = defaultThresholds,
  }) {
    return _assessLuma(image.width, image.height, thresholds, (x, y) {
      final p = image.getPixel(x, y);
      return (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).toDouble();
    });
  }

  /// Assesses a live [CameraImage] frame in real time, from the Y
  /// (luminance) plane directly.
  static QualityAssessment assessCameraImage(
    CameraImage cameraImage, {
    QualityThresholds thresholds = defaultThresholds,
  }) {
    try {
      final plane = cameraImage.planes.first;
      final bytes = plane.bytes;
      final bytesPerRow = plane.bytesPerRow;
      return _assessLuma(cameraImage.width, cameraImage.height, thresholds,
          (x, y) {
        final i = y * bytesPerRow + x;
        return i < bytes.length ? bytes[i].toDouble() : 0.0;
      });
    } catch (_) {
      return QualityAssessment.checking;
    }
  }

  /// Side of the square grid the blur and light are measured on.
  static const int _grid = 160;

  /// Measures the centre square (60% of the shorter side), shrunk to a
  /// [_grid] x [_grid] luminance grid by averaging. Shrinking first means blur
  /// is judged near the scale the model sees (it gets the frame at 224 px),
  /// so smooth skin or slight motion that the model can't notice isn't
  /// called blurry. Each cell averages up to 4 x 4 evenly spaced pixels.
  static QualityAssessment _assessLuma(
    int width,
    int height,
    QualityThresholds thresholds,
    double Function(int x, int y) lumaAt,
  ) {
    final side = (math.min(width, height) * 0.6).floor();
    if (side < 8) return QualityAssessment.checking;
    final startX = (width - side) ~/ 2;
    final startY = (height - side) ~/ 2;
    final n = math.min(side, _grid);
    final cell = side / n;
    final taps = math.max(1, math.min(4, cell.floor()));

    final grid = List.generate(n, (_) => Float32List(n), growable: false);
    double sumLuminance = 0.0;
    for (var gy = 0; gy < n; gy++) {
      final row = grid[gy];
      for (var gx = 0; gx < n; gx++) {
        var sum = 0.0;
        for (var ty = 0; ty < taps; ty++) {
          final y = startY + ((gy + (ty + 0.5) / taps) * cell).floor();
          for (var tx = 0; tx < taps; tx++) {
            final x = startX + ((gx + (tx + 0.5) / taps) * cell).floor();
            sum += lumaAt(x, y);
          }
        }
        final lum = sum / (taps * taps);
        row[gx] = lum;
        sumLuminance += lum;
      }
    }

    final meanIntensity = sumLuminance / (n * n);
    final lapVariance = _computeLaplacianVariance(grid, n, n);
    return _evaluate(lapVariance, meanIntensity, thresholds);
  }

  /// Judges [a] again against a stricter blur limit, e.g. one set relative to
  /// the sharpest recent frame of the same scene.
  static QualityAssessment rejudge(
    QualityAssessment a, {
    required double blurMin,
    QualityThresholds thresholds = defaultThresholds,
  }) {
    if (a.focus == FocusStatus.checking) return a;
    return _evaluate(
      a.blurScore,
      a.lightScore,
      QualityThresholds(
        blurMinVariance: math.max(thresholds.blurMinVariance, blurMin),
        lightMinIntensity: thresholds.lightMinIntensity,
        lightMaxIntensity: thresholds.lightMaxIntensity,
      ),
    );
  }

  /// Computes the variance of the 4-neighbor discrete Laplacian operator:
  /// L(x,y) = I(x+1,y) + I(x-1,y) + I(x,y+1) + I(x,y-1) - 4*I(x,y)
  static double _computeLaplacianVariance(
    List<Float32List> grid,
    int width,
    int height,
  ) {
    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      final prevRow = grid[y - 1];
      final currRow = grid[y];
      final nextRow = grid[y + 1];

      for (int x = 1; x < width - 1; x++) {
        final l = prevRow[x] + nextRow[x] + currRow[x - 1] + currRow[x + 1] - (4.0 * currRow[x]);
        sum += l;
        sumSq += l * l;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return math.max(0.0, variance);
  }

  static QualityAssessment _evaluate(
    double blurScore,
    double lightScore,
    QualityThresholds thresholds,
  ) {
    final focus = blurScore >= thresholds.blurMinVariance
        ? FocusStatus.sharp
        : FocusStatus.blurry;

    final LightStatus light;
    if (lightScore < 28) {
      light = LightStatus.tooDark;
    } else if (lightScore < thresholds.lightMinIntensity) {
      light = LightStatus.lowLight;
    } else if (lightScore > thresholds.lightMaxIntensity) {
      light = LightStatus.tooBright;
    } else {
      light = LightStatus.adequate;
    }

    final isAcceptable = (focus == FocusStatus.sharp) && (light == LightStatus.adequate);

    final String feedback;
    if (!isAcceptable) {
      if (focus == FocusStatus.blurry && (light == LightStatus.tooDark || light == LightStatus.lowLight)) {
        feedback = 'Keep the phone still and find brighter light.';
      } else if (focus == FocusStatus.blurry) {
        feedback = 'Keep the phone still over the affected area.';
      } else if (light == LightStatus.tooDark || light == LightStatus.lowLight) {
        feedback = 'Lighting is dim. Point towards brighter light.';
      } else {
        feedback = 'Lighting is too bright. Reduce direct glare.';
      }
    } else {
      feedback = 'Keep the phone still over the affected area.';
    }

    return QualityAssessment(
      blurScore: blurScore,
      lightScore: lightScore,
      focus: focus,
      light: light,
      isAcceptable: isAcceptable,
      feedbackMessage: feedback,
    );
  }
}
