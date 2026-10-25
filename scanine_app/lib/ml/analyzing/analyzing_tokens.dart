// lib/ml/analyzing/analyzing_tokens.dart
// Ported from scanine_analyzing.zip — imports adapted.
import 'package:flutter/material.dart';

/// Colours of the Analyzing screen: the splash palette and nothing else.
@immutable
class AnalyzingTokens extends ThemeExtension<AnalyzingTokens> {
  const AnalyzingTokens({
    required this.navy,
    required this.cloud,
    required this.cloudDeep,
    required this.slate,
    required this.scanGrey,
    required this.gridLine,
    required this.gridLineOpacity,
    required this.gridAxis,
    required this.gridAxisOpacity,
    required this.stageScrim,
    required this.stageScrimOpacity,
  });

  /// Splash palette — the canonical token values.
  static const AnalyzingTokens splash = AnalyzingTokens(
    navy: Color(0xFF203661),
    cloud: Color(0xFFF4F5FA),
    cloudDeep: Color(0xFFE8EBF2),
    slate: Color(0xFF6B7090),
    scanGrey: Color(0xFFC4CAD8),
    gridLine: Color(0xFFFFFFFF),
    gridLineOpacity: 0.22,
    gridAxis: Color(0xFFE8EBF2),
    gridAxisOpacity: 0.50,
    stageScrim: Color(0xFF203661),
    stageScrimOpacity: 0.42,
  );

  final Color navy;
  final Color cloud;
  final Color cloudDeep;
  final Color slate;
  final Color scanGrey;
  final Color gridLine;
  final double gridLineOpacity;
  final Color gridAxis;
  final double gridAxisOpacity;
  final Color stageScrim;
  final double stageScrimOpacity;

  static AnalyzingTokens of(BuildContext context) =>
      Theme.of(context).extension<AnalyzingTokens>() ?? splash;

  @override
  AnalyzingTokens copyWith({
    Color? navy,
    Color? cloud,
    Color? cloudDeep,
    Color? slate,
    Color? scanGrey,
    Color? gridLine,
    double? gridLineOpacity,
    Color? gridAxis,
    double? gridAxisOpacity,
    Color? stageScrim,
    double? stageScrimOpacity,
  }) {
    return AnalyzingTokens(
      navy: navy ?? this.navy,
      cloud: cloud ?? this.cloud,
      cloudDeep: cloudDeep ?? this.cloudDeep,
      slate: slate ?? this.slate,
      scanGrey: scanGrey ?? this.scanGrey,
      gridLine: gridLine ?? this.gridLine,
      gridLineOpacity: gridLineOpacity ?? this.gridLineOpacity,
      gridAxis: gridAxis ?? this.gridAxis,
      gridAxisOpacity: gridAxisOpacity ?? this.gridAxisOpacity,
      stageScrim: stageScrim ?? this.stageScrim,
      stageScrimOpacity: stageScrimOpacity ?? this.stageScrimOpacity,
    );
  }

  @override
  AnalyzingTokens lerp(ThemeExtension<AnalyzingTokens>? other, double t) {
    if (other is! AnalyzingTokens) return this;
    return AnalyzingTokens(
      navy: Color.lerp(navy, other.navy, t)!,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      cloudDeep: Color.lerp(cloudDeep, other.cloudDeep, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      scanGrey: Color.lerp(scanGrey, other.scanGrey, t)!,
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      gridLineOpacity: _lerp(gridLineOpacity, other.gridLineOpacity, t),
      gridAxis: Color.lerp(gridAxis, other.gridAxis, t)!,
      gridAxisOpacity: _lerp(gridAxisOpacity, other.gridAxisOpacity, t),
      stageScrim: Color.lerp(stageScrim, other.stageScrim, t)!,
      stageScrimOpacity: _lerp(stageScrimOpacity, other.stageScrimOpacity, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// [c] at opacity [o] (0..1), without reading the colour's own alpha.
Color withOpacityF(Color c, double o) {
  final a = (o * 255).round();
  return c.withAlpha(a < 0 ? 0 : (a > 255 ? 255 : a));
}
