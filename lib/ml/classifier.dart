import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// One frame's inference result.
class FrameResult {
  final String label; // 'Ringworm' | 'Normal'
  final double ringwormProb; // raw sigmoid output
  final double confidence; // confidence in `label`
  final Float32List cam; // camH * camW, normalised 0..1
  final int camH, camW;

  const FrameResult({
    required this.label,
    required this.ringwormProb,
    required this.confidence,
    required this.cam,
    required this.camH,
    required this.camW,
  });
}

/// Scanine's on-device classifier.
///
/// The exported model has two outputs: the sigmoid probability and the
/// final convolutional feature maps (7x7x576). Grad-CAM's channel weights
/// are dY/dP where P is the globally-pooled feature vector, and because the
/// head is only BatchNorm -> Dense(128, relu) -> Dense(1) that derivative
/// has a closed form:
///
///   alpha[k] = (gamma[k]/sqrt(var[k]+eps)) * SUM_j W1[k][j]*W2[j]*[pre_j>0]
///
/// So no autodiff is needed on device — just ~74k multiply-adds. This was
/// verified against a numerical gradient before being ported here.
class Classifier {
  Interpreter? _it;
  List<String> _labels = const ['Normal', 'Ringworm'];

  late int _inSize;
  late int _featIdx, _probIdx;
  late int _camH, _camW, _channels;
  late int _hidden;

  // Head parameters, unpacked from head.bin.
  late Float32List _invStd, _beta, _mean, _w1, _b1, _w2;
  late double _b2;

  bool get isReady => _it != null;

  Future<void> load() async {
    final interpreter =
        await Interpreter.fromAsset('assets/model/scanine.tflite');
    interpreter.allocateTensors();

    _inSize = interpreter.getInputTensor(0).shape[1];

    // Output order is not guaranteed by the converter, so identify the
    // tensors by rank: the 4-D one is the feature map.
    _featIdx = -1;
    _probIdx = -1;
    for (var i = 0; i < 2; i++) {
      final shape = interpreter.getOutputTensor(i).shape;
      if (shape.length == 4) {
        _featIdx = i;
        _camH = shape[1];
        _camW = shape[2];
        _channels = shape[3];
      } else {
        _probIdx = i;
      }
    }
    if (_featIdx < 0 || _probIdx < 0) {
      throw StateError('Expected one 4-D and one 2-D output tensor.');
    }

    _labels = (await rootBundle.loadString('assets/model/labels.txt'))
        .trim()
        .split('\n')
        .map((s) => s.trim())
        .toList();

    await _loadHead();
    _it = interpreter;
  }

  Future<void> _loadHead() async {
    final data = await rootBundle.load('assets/model/head.bin');
    final all = data.buffer
        .asFloat32List(data.offsetInBytes, data.lengthInBytes ~/ 4);

    final c = _channels;
    // Layout written by export_tflite.py:
    //   gamma[c], beta[c], moving_mean[c], moving_var[c],
    //   W1[c*hidden], b1[hidden], W2[hidden], b2[1]
    final expectedWithoutHidden = 4 * c;
    final remaining = all.length - expectedWithoutHidden - 1;
    _hidden = remaining ~/ (c + 2); // c*h + h + h  ==  h*(c+2)

    var o = 0;
    final gamma = Float32List.fromList(all.sublist(o, o + c));
    o += c;
    _beta = Float32List.fromList(all.sublist(o, o + c));
    o += c;
    _mean = Float32List.fromList(all.sublist(o, o + c));
    o += c;
    final variance = all.sublist(o, o + c);
    o += c;
    _w1 = Float32List.fromList(all.sublist(o, o + c * _hidden));
    o += c * _hidden;
    _b1 = Float32List.fromList(all.sublist(o, o + _hidden));
    o += _hidden;
    _w2 = Float32List.fromList(all.sublist(o, o + _hidden));
    o += _hidden;
    _b2 = all[o];
    o += 1;

    if (o != all.length) {
      throw StateError('head.bin is ${all.length} floats, consumed $o.');
    }

    // Fold BatchNorm's scale into one multiplier: gamma / sqrt(var + eps).
    const eps = 1e-3;
    _invStd = Float32List(c);
    for (var k = 0; k < c; k++) {
      _invStd[k] = gamma[k] / math.sqrt(variance[k] + eps);
    }
  }

  /// Decode and classify one photo.
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
    final base = img.copyResize(await _decode(path),
        width: _inSize, height: _inSize);

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
    final decoded = img.decodeImage(await File(path).readAsBytes());
    if (decoded == null) throw StateError('Could not decode $path');
    return decoded;
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
    if (interpreter == null) throw StateError('Classifier.load() not called.');

    final resized = (source.width == _inSize && source.height == _inSize)
        ? source
        : img.copyResize(source, width: _inSize, height: _inSize);

    // Model expects float32 pixels in 0..255; the /255 and the backbone's
    // own preprocessing both live inside the graph.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inSize,
        (y) => List.generate(_inSize, (x) {
          final p = resized.getPixel(x, y);
          return <double>[
            p.r.toDouble(),
            p.g.toDouble(),
            p.b.toDouble(),
          ];
        }),
      ),
    );

    final featOut = List.generate(
      1,
      (_) => List.generate(
        _camH,
        (_) => List.generate(_camW, (_) => List<double>.filled(_channels, 0)),
      ),
    );
    final probOut = [List<double>.filled(1, 0)];

    interpreter.runForMultipleInputs([input], {
      _featIdx: featOut,
      _probIdx: probOut,
    });

    final prob = probOut[0][0];
    final feat = featOut[0];

    return FrameResult(
      label: prob >= 0.5 ? _labels[1] : _labels[0],
      ringwormProb: prob,
      confidence: prob >= 0.5 ? prob : 1.0 - prob,
      cam: _gradCam(feat, prob),
      camH: _camH,
      camW: _camW,
    );
  }

  /// Closed-form Grad-CAM. See the class comment for the derivation.
  Float32List _gradCam(List<List<List<double>>> feat, double tfliteProb) {
    final c = _channels;
    final h = _hidden;
    final cells = _camH * _camW;

    // Global average pool -> p, then BatchNorm -> z.
    final z = Float32List(c);
    for (var k = 0; k < c; k++) {
      var sum = 0.0;
      for (var y = 0; y < _camH; y++) {
        for (var x = 0; x < _camW; x++) {
          sum += feat[y][x][k];
        }
      }
      final p = sum / cells;
      z[k] = _invStd[k] * (p - _mean[k]) + _beta[k];
    }

    // Hidden activations: their sign decides which ReLU units are open,
    // and their values let us re-derive the probability as a self-check.
    final hAct = Float32List(h);
    final open = List<bool>.filled(h, false);
    for (var j = 0; j < h; j++) {
      var acc = _b1[j];
      for (var k = 0; k < c; k++) {
        acc += z[k] * _w1[k * h + j];
      }
      hAct[j] = acc > 0 ? acc : 0.0;
      open[j] = acc > 0;
    }

    // Debug-only integrity check: running the head forward from the feature
    // maps must reproduce the probability TFLite just returned. If it does
    // not, head.bin no longer matches the exported model and every Grad-CAM
    // map would be silently wrong. Asserts are stripped from release builds.
    assert(() {
      var y = _b2;
      for (var j = 0; j < h; j++) {
        y += hAct[j] * _w2[j];
      }
      final reconstructed = 1.0 / (1.0 + math.exp(-y));
      final diff = (reconstructed - tfliteProb).abs();
      if (diff > 1e-3) {
        throw StateError(
            'head.bin does not match the model: reconstructed '
            '\$reconstructed vs TFLite \$tfliteProb (diff \$diff)');
      }
      return true;
    }());

    // alpha[k] = invStd[k] * SUM_j W1[k][j] * W2[j] * [open_j]
    final alpha = Float32List(c);
    for (var k = 0; k < c; k++) {
      var acc = 0.0;
      final row = k * h;
      for (var j = 0; j < h; j++) {
        if (open[j]) acc += _w1[row + j] * _w2[j];
      }
      alpha[k] = _invStd[k] * acc;
    }

    // Weighted sum over channels, then ReLU.
    final cam = Float32List(cells);
    var maxV = 0.0;
    for (var y = 0; y < _camH; y++) {
      for (var x = 0; x < _camW; x++) {
        var acc = 0.0;
        final px = feat[y][x];
        for (var k = 0; k < c; k++) {
          acc += px[k] * alpha[k];
        }
        final v = acc > 0 ? acc : 0.0;
        cam[y * _camW + x] = v;
        if (v > maxV) maxV = v;
      }
    }

    if (maxV > 0) {
      for (var i = 0; i < cam.length; i++) {
        cam[i] = cam[i] / maxV;
      }
    }
    return cam;
  }

  void close() {
    _it?.close();
    _it = null;
  }
}
