// lib/ml/analyzing/analyze_clock.dart
// Ported from scanine_analyzing.zip — imports adapted.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'analyze_timeline.dart';
import 'heat_grid.dart';

/// Behaviour switches of the Analyzing screen.
@immutable
class AnalyzingConfig {
  const AnalyzingConfig({
    this.speed = 1.0,
    this.forceMode,
    this.detectLowEnd = !kDebugMode,
    this.resultOverlayOpacity = HeatGrid.maxCellAlpha,
    this.resultScrimFactor = 0.0,
    this.heroTag = AnalyzingHeroTags.photo,
  });

  final double speed;
  final AnalyzeMode? forceMode;
  final bool detectLowEnd;
  final double resultOverlayOpacity;
  final double resultScrimFactor;
  final Object heroTag;
}

abstract final class AnalyzingHeroTags {
  static const String photo = 'scanine.analyzing.photo';
}

/// State shared between the screen and its three painters.
class AnalyzeClock {
  AnalyzeClock({
    required this.main,
    required this.loop,
    required this.columns,
    required this.rows,
    required this.config,
    required this.mode,
    required this.onError,
  }) : repaint = Listenable.merge([main, loop]);

  final Animation<double> main;
  final Animation<double> loop;
  final int columns;
  int rows;
  final AnalyzingConfig config;
  final void Function(Object error, StackTrace stack) onError;
  final Listenable repaint;

  AnalyzeMode mode;
  bool waiting = false;
  HeatGrid? grid;

  /// Smooth 56x56 version of the heat (white, alpha = heat) for the hand-off.
  ui.Image? overlay;

  bool _errored = false;

  AnalyzeFrame frame() => AnalyzeTimeline.frameAt(
    main.value,
    mode: mode,
    waitLoop: waiting ? loop.value : null,
  );

  void guard(VoidCallback body) {
    try {
      body();
    } catch (e, s) {
      if (_errored) return;
      _errored = true;
      onError(e, s);
    }
  }
}
