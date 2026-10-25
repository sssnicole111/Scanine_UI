// lib/ml/analyzing/input_mapping.dart
// Verbatim from scanine_analyzing.zip — no changes needed.
import 'dart:math' as math;

/// An axis-aligned rectangle in normalised (0..1) coordinates.
class NormRect {
  const NormRect(this.left, this.top, this.right, this.bottom);

  static const NormRect unit = NormRect(0, 0, 1, 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  @override
  String toString() => 'NormRect($left, $top, $right, $bottom)';
}

/// Describes how the model's input relates to the full captured image.
class InputMapping {
  const InputMapping({this.seen = NormRect.unit, this.placed = NormRect.unit});

  /// The whole image is resized (stretched) to the model input.
  const InputMapping.stretch() : this();

  /// Resize so the input is covered, then centre-crop the overflow.
  factory InputMapping.centerCrop({
    required int imageWidth,
    required int imageHeight,
    required int inputWidth,
    required int inputHeight,
  }) {
    _check(imageWidth, imageHeight, inputWidth, inputHeight);
    final scale = math.max(inputWidth / imageWidth, inputHeight / imageHeight);
    final seenW = inputWidth / scale / imageWidth;
    final seenH = inputHeight / scale / imageHeight;
    final l = (1 - seenW) / 2;
    final t = (1 - seenH) / 2;
    return InputMapping(seen: NormRect(l, t, l + seenW, t + seenH));
  }

  /// Resize so the whole image fits, then pad the rest (letterbox).
  factory InputMapping.letterbox({
    required int imageWidth,
    required int imageHeight,
    required int inputWidth,
    required int inputHeight,
  }) {
    _check(imageWidth, imageHeight, inputWidth, inputHeight);
    final scale = math.min(inputWidth / imageWidth, inputHeight / imageHeight);
    final placedW = imageWidth * scale / inputWidth;
    final placedH = imageHeight * scale / inputHeight;
    final l = (1 - placedW) / 2;
    final t = (1 - placedH) / 2;
    return InputMapping(placed: NormRect(l, t, l + placedW, t + placedH));
  }

  final NormRect seen;
  final NormRect placed;

  ({double u, double v})? imageToInput(double x, double y) {
    if (!seen.contains(x, y)) return null;
    final u = placed.left + (x - seen.left) / seen.width * placed.width;
    final v = placed.top + (y - seen.top) / seen.height * placed.height;
    return (u: u, v: v);
  }

  static void _check(int iw, int ih, int nw, int nh) {
    if (iw <= 0 || ih <= 0 || nw <= 0 || nh <= 0) {
      throw ArgumentError('Image and input sizes must be positive.');
    }
  }
}
