import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// One frame's inference result.
class FrameResult {
  final String label; // predicted class name
  final List<double> probabilities; // softmax outputs for all classes
  final double confidence; // max probability (confidence in `label`)
  final Float32List cam; // camH * camW, normalised 0..1
  final int camH, camW;

  const FrameResult({
    required this.label,
    required this.probabilities,
    required this.confidence,
    required this.cam,
    required this.camH,
    required this.camW,
  });

  /// Backward-compat: probability of ringworm specifically.
  double get ringwormProb =>
      probabilities.isNotEmpty ? probabilities[0] : 0.0;

  /// Shannon entropy of the probability distribution, normalised to [0, 1].
  /// A value near 1.0 means the model is maximally uncertain (all classes
  /// equally likely). A value near 0.0 means the model is very confident.
  double get entropy {
    if (probabilities.isEmpty) return 1.0;
    final n = probabilities.length;
    var h = 0.0;
    for (final p in probabilities) {
      if (p > 1e-12) h -= p * math.log(p);
    }
    // Normalise by ln(n) so the result is in [0, 1].
    return h / math.log(n);
  }

  /// Margin between the top-1 and top-2 probabilities.
  /// A small margin (< ~0.15) means the model is nearly tied between classes.
  double get margin {
    if (probabilities.length < 2) return confidence;
    final sorted = [...probabilities]..sort((a, b) => b.compareTo(a));
    return sorted[0] - sorted[1];
  }
}

/// Scanine's on-device classifier.
///
/// Model run: 20261029_1757_mnv3s_baseline_seed42  (1,735-image dataset)
///   Architecture : MobileNetV3-Small baseline (USE_CA=false, dropout=0.3)
///   Test accuracy: 93.9 % (n=261, 95% CI 90.8-96.6)  |  macro-AUC: 0.990
///   Per-class F1 : Ringworm 0.897, Hotspot 0.940, FAD 0.909, Healthy 0.983
///
/// The 4-class model outputs:
///   - Grad-CAM heatmap [1, 7, 7] at output index 0
///   - Softmax probabilities [1, 4] at output index 1
///   (Ringworm, Hotspot, FAD, Healthy)
///
/// Asset: assets/model/scanine.tflite  (fp32, 3.76 MB)
/// We use fp32 (max_prob_diff < 7e-6 vs Keras). fp16 (1.94 MB) gives the same
/// test accuracy (max_prob_diff 0.010); int8-dynamic: max_prob_diff 0.32.
///
/// Implemented as a singleton with concurrent-safe asynchronous loading,
/// EXIF orientation baking, and multi-threaded CPU acceleration.
class Classifier {
  Classifier._();
  static final Classifier instance = Classifier._();
  factory Classifier() => instance;

  Interpreter? _it;
  List<String> _labels = const [];
  Future<void>? _loadingFuture;

  // Fixed tensor indices from metrics.json tflite_io section:
  //   output[0] → gradcam [1, 7, 7]
  //   output[1] → probabilities [1, 4]
  static const int _camIdx = 0;
  static const int _probIdx = 1;
  static const int _camH = 7;
  static const int _camW = 7;
  static const int _numClasses = 4;
  static const int _inSize = 224;

  bool get isReady => _it != null;
  List<String> get labels => List.unmodifiable(_labels);

  /// Loads the TFLite model and labels. Safe to call multiple times concurrently.
  Future<void> load() async {
    if (isReady) return;
    return _loadingFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      final interpreter = await Interpreter.fromAsset(
        'assets/model/scanine.tflite',
        options: options,
      );
      interpreter.allocateTensors();

      // Sanity-check that the model shapes match our fixed constants.
      final camShape = interpreter.getOutputTensor(_camIdx).shape;
      final probShape = interpreter.getOutputTensor(_probIdx).shape;
      if (camShape.length != 3 ||
          camShape[1] != _camH ||
          camShape[2] != _camW) {
        throw StateError(
          'CAM output[0] expected shape [1,$_camH,$_camW], got $camShape',
        );
      }
      if (probShape.length != 2 || probShape[1] != _numClasses) {
        throw StateError(
          'Prob output[1] expected shape [1,$_numClasses], got $probShape',
        );
      }

      final labelData = await rootBundle.loadString('assets/model/labels.txt');
      _labels = labelData
          .trim()
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (_labels.length != _numClasses) {
        throw StateError(
          'labels.txt has ${_labels.length} entries; expected $_numClasses',
        );
      }

      _it = interpreter;
    } catch (e) {
      _loadingFuture = null;
      rethrow;
    }
  }

  /// Decode and classify one photo file.
  Future<FrameResult> classifyFile(String path) async {
    return classifyImage(await _decode(path));
  }

  /// Classify one uploaded photo five times under test-time augmentation.
  ///
  /// A single upload cannot support the five-frame vote the camera gets:
  /// the model is deterministic, so running the same pixels five times
  /// returns the same number five times and "5/5 agreed" would mean
  /// nothing. Five *augmented* views are genuinely different inputs, so
  /// the vote measures something real — and the transforms mirror the ones
  /// the model was trained under (horizontal flip, rotation, zoom).
  ///
  /// Index 0 is always the untransformed view. Its Grad-CAM is the only
  /// one that aligns with the original photo, so that is the map to show.
  Future<List<FrameResult>> classifyFileTta(String path) async {
    final decoded = await _decode(path);
    final base = (decoded.width == _inSize && decoded.height == _inSize)
        ? decoded
        : img.copyResize(decoded, width: _inSize, height: _inSize);

    final views = <img.Image>[
      base, // identity — Grad-CAM source
      img.flipHorizontal(base),
      _centreCrop(base, 0.88), // zoom
      _centreCrop(img.flipHorizontal(base), 0.88),
      // Rotating pads the canvas; cropping to 0.78 of the padded result
      // discards the filled corners so the model never sees blank wedges.
      _centreCrop(img.copyRotate(base, angle: 8), 0.78),
    ];

    final out = <FrameResult>[];
    for (final v in views) {
      out.add(classifyImage(v));
      await Future<void>.delayed(Duration.zero);
    }
    return out;
  }

  Future<img.Image> _decode(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Image file does not exist: $path');
    }
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image at: $path');
    }
    // Bake EXIF orientation so photos taken from mobile camera sensors
    // are physically upright before being fed into the neural network.
    return img.bakeOrientation(decoded);
  }

  img.Image _centreCrop(img.Image src, double frac) {
    final w = (src.width * frac).round();
    final h = (src.height * frac).round();
    final x = ((src.width - w) / 2).round();
    final y = ((src.height - h) / 2).round();
    return img.copyResize(
      img.copyCrop(src, x: x, y: y, width: w, height: h),
      width: _inSize,
      height: _inSize,
    );
  }

  /// Classify an already-decoded image, returning the label, the confidence
  /// and a normalised Grad-CAM map.
  FrameResult classifyImage(img.Image source) {
    final interpreter = _it;
    if (interpreter == null) {
      throw StateError('Classifier.load() must be completed before inference.');
    }

    final resized = (source.width == _inSize && source.height == _inSize)
        ? source
        : img.copyResize(
            source,
            width: _inSize,
            height: _inSize,
            interpolation: img.Interpolation.linear,
          );

    // Preprocessing: (pixel - 127.5) / 127.5  →  range [-1, 1]
    // This matches the graph's expected input documented in metrics.json.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inSize,
        (y) => List.generate(_inSize, (x) {
          final p = resized.getPixel(x, y);
          return <double>[
            (p.r.toDouble() - 127.5) / 127.5,
            (p.g.toDouble() - 127.5) / 127.5,
            (p.b.toDouble() - 127.5) / 127.5,
          ];
        }),
      ),
    );

    // Grad-CAM output: [1, 7, 7]
    final camOut = List.generate(
      1,
      (_) => List.generate(_camH, (_) => List<double>.filled(_camW, 0.0)),
    );
    // Probabilities output: [1, 4]
    final probOut = [List<double>.filled(_numClasses, 0.0)];

    interpreter.runForMultipleInputs([input], {
      _camIdx: camOut,
      _probIdx: probOut,
    });

    final probs = probOut[0];

    // Find the argmax class.
    var bestIdx = 0;
    var bestProb = probs.isNotEmpty ? probs[0] : 0.0;
    for (var i = 1; i < _numClasses; i++) {
      if (probs[i] > bestProb) {
        bestProb = probs[i];
        bestIdx = i;
      }
    }

    // Flatten and normalise the Grad-CAM map.
    final cam = _normaliseCam(camOut[0]);

    return FrameResult(
      label: bestIdx < _labels.length ? _labels[bestIdx] : 'Unknown',
      probabilities: List<double>.unmodifiable(probs),
      confidence: bestProb,
      cam: cam,
      camH: _camH,
      camW: _camW,
    );
  }

  /// Flatten the 2-D cam array to a 1-D Float32List and normalise to 0..1.
  Float32List _normaliseCam(List<List<double>> cam2d) {
    final cells = _camH * _camW;
    final cam = Float32List(cells);
    var maxV = 0.0;

    for (var y = 0; y < _camH; y++) {
      for (var x = 0; x < _camW; x++) {
        final raw = cam2d[y][x];
        // ReLU: clamp negatives and invalid floats
        final v = raw.isFinite && raw > 0 ? raw : 0.0;
        cam[y * _camW + x] = v;
        if (v > maxV) maxV = v;
      }
    }

    if (maxV > 1e-6) {
      for (var i = 0; i < cam.length; i++) {
        cam[i] = cam[i] / maxV;
      }
    }
    return cam;
  }

  void close() {
    _it?.close();
    _it = null;
    _loadingFuture = null;
  }
}
