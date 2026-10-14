import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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
    this.blurMinVariance = 80.0,
    this.lightMinIntensity = 42.0,
    this.lightMaxIntensity = 222.0,
  });

  /// Minimum variance of the Laplacian operator for an image to be deemed 'Sharp'.
  final double blurMinVariance;

  /// Minimum mean pixel luminance (0..255) for adequate lighting.
  final double lightMinIntensity;

  /// Maximum mean pixel luminance (0..255) before an image is considered overexposed.
  final double lightMaxIntensity;
}

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
    feedbackMessage: 'Hold steady over the affected area.',
  );
}

/// Quality gate implementation executing real-time Laplacian variance (blur)
/// and Mean Pixel Intensity (lighting) assessments.
class QualityGate {
  static const QualityThresholds defaultThresholds = QualityThresholds();

  /// Assesses a captured image file from disk.
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
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return QualityAssessment.checking;
      }

      return assessDecodedImage(decoded, thresholds: thresholds);
    } catch (_) {
      return QualityAssessment.checking;
    }
  }

  /// Assesses an [img.Image] decoded in memory.
  static QualityAssessment assessDecodedImage(
    img.Image image, {
    QualityThresholds thresholds = defaultThresholds,
  }) {
    // Sample a center crop (e.g. 180x180) to evaluate the region of interest
    const sampleSize = 160;
    final w = image.width;
    final h = image.height;
    final startX = math.max(0, (w - sampleSize) ~/ 2);
    final startY = math.max(0, (h - sampleSize) ~/ 2);
    final actualW = math.min(sampleSize, w - startX);
    final actualH = math.min(sampleSize, h - startY);

    if (actualW < 4 || actualH < 4) {
      return QualityAssessment.checking;
    }

    // Extract 2D grayscale luminance array
    final grid = List.generate(
      actualH,
      (y) => Float32List(actualW),
      growable: false,
    );

    double sumLuminance = 0.0;
    final totalPixels = actualW * actualH;

    for (int y = 0; y < actualH; y++) {
      for (int x = 0; x < actualW; x++) {
        final pixel = image.getPixel(startX + x, startY + y);
        // Standard Rec. 601 luminance
        final lum = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toDouble();
        grid[y][x] = lum;
        sumLuminance += lum;
      }
    }

    final meanIntensity = sumLuminance / totalPixels;
    final lapVariance = _computeLaplacianVariance(grid, actualW, actualH);

    return _evaluate(lapVariance, meanIntensity, thresholds);
  }

  /// Assesses a live [CameraImage] frame in real time.
  /// Inspects the Y (luminance) plane directly for zero-copy performance.
  static QualityAssessment assessCameraImage(
    CameraImage cameraImage, {
    QualityThresholds thresholds = defaultThresholds,
  }) {
    try {
      final plane = cameraImage.planes.first;
      final bytes = plane.bytes;
      final width = cameraImage.width;
      final height = cameraImage.height;
      final bytesPerRow = plane.bytesPerRow;

      // Focus on the center crop corresponding to the reticle
      const sampleSize = 140;
      final startX = math.max(0, (width - sampleSize) ~/ 2);
      final startY = math.max(0, (height - sampleSize) ~/ 2);
      final actualW = math.min(sampleSize, width - startX);
      final actualH = math.min(sampleSize, height - startY);

      if (actualW < 4 || actualH < 4) {
        return QualityAssessment.checking;
      }

      final grid = List.generate(
        actualH,
        (y) => Float32List(actualW),
        growable: false,
      );

      double sumLuminance = 0.0;
      final totalPixels = actualW * actualH;

      for (int y = 0; y < actualH; y++) {
        final rowOffset = (startY + y) * bytesPerRow;
        for (int x = 0; x < actualW; x++) {
          final index = rowOffset + (startX + x);
          if (index < bytes.length) {
            final lum = bytes[index].toDouble();
            grid[y][x] = lum;
            sumLuminance += lum;
          }
        }
      }

      final meanIntensity = sumLuminance / totalPixels;
      final lapVariance = _computeLaplacianVariance(grid, actualW, actualH);

      return _evaluate(lapVariance, meanIntensity, thresholds);
    } catch (_) {
      return QualityAssessment.checking;
    }
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
        feedback = 'Hold steady and increase lighting.';
      } else if (focus == FocusStatus.blurry) {
        feedback = 'Hold steady over the affected area.';
      } else if (light == LightStatus.tooDark || light == LightStatus.lowLight) {
        feedback = 'Lighting is dim. Point towards brighter light.';
      } else {
        feedback = 'Lighting is too bright. Reduce direct glare.';
      }
    } else {
      feedback = 'Hold steady over the affected area.';
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
