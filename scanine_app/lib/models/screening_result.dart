import 'dart:typed_data';

import '../ml/classifier.dart';
import 'guidance_data.dart';

export 'guidance_data.dart' show GuidanceStep, TriageProtocol;

/// Clinical priority for triage and referral routing.
///
/// Condition-level priority (static per condition), not patient-specific severity.
enum Urgency { high, medium, low }

class ScreeningResult {
  final String condition;
  final String conditionLabel;
  final double confidence;
  final int agreeVotes;
  final int totalFrames;
  final Urgency urgency;
  final String referralText;
  final TriageProtocol? protocol;
  final String? imagePath;
  final Uint8List? heatmap;
  final bool inconclusive;

  /// True when the dog check found no dog and the user continued anyway.
  /// The classifier is not run: it only knows four skin conditions and would
  /// always name one of them, even for a photo of text.
  final bool notDog;

  /// True when the vote came from augmented views of one uploaded
  /// photo rather than from five separately captured frames.
  final bool tta;

  const ScreeningResult({
    required this.condition,
    required this.conditionLabel,
    required this.confidence,
    required this.agreeVotes,
    required this.totalFrames,
    required this.urgency,
    required this.referralText,
    this.protocol,
    this.imagePath,
    this.heatmap,
    this.inconclusive = false,
    this.tta = false,
    this.notDog = false,
  });

  /// Result for an upload the dog check rejected. Shown like an inconclusive
  /// result (no condition, no heatmap) with its own wording.
  factory ScreeningResult.noDog({required String imagePath}) =>
      ScreeningResult(
        condition: 'No dog found',
        conditionLabel: 'No dog found',
        confidence: 0.0,
        agreeVotes: 0,
        totalFrames: 0,
        urgency: Urgency.low,
        referralText: 'Choose another photo',
        protocol: null,
        imagePath: imagePath,
        inconclusive: true,
        tta: true,
        notDog: true,
      );

  int get confidencePercent => (confidence * 100).round();
  bool get hasHeatmap => heatmap != null;

  /// Majority vote across the captured frames, with confidence and entropy
  /// gates derived from the model's threshold_table.csv and metrics.json.
  ///
  /// Abstention rules (any one triggers inconclusive):
  ///   1. Mean confidence of agreeing frames < [abstainBelow] (0.70)
  ///   2. Mean normalised entropy of agreeing frames > [maxEntropy] (0.45)
  ///      — catches cases where the top two probs are nearly tied
  ///   3. For a 5-frame live burst: fewer than 3 frames agree on the winner
  ///
  /// With the Coordinate Attention model (20261029_1846) the 0.70 threshold
  /// gives 95.7% selective accuracy on validation (answering 90.0%) and 94.0%
  /// on the test set (answering 89.3%) (threshold_table.csv). 0.70 is also
  /// the notebook's own suggestion for this run.
  factory ScreeningResult.fromFrames({
    required List<FrameResult> frames,
    required String imagePath,
    Uint8List? heatmap,
    double abstainBelow = 0.70,
    double maxEntropy = 0.45,
    bool tta = false,
  }) {
    if (frames.isEmpty) {
      return ScreeningResult(
        condition: 'Inconclusive',
        conditionLabel: 'Inconclusive',
        confidence: 0.0,
        agreeVotes: 0,
        totalFrames: 0,
        urgency: Urgency.medium,
        referralText: 'Refer to veterinarian',
        protocol: null,
        imagePath: imagePath,
        heatmap: heatmap,
        inconclusive: true,
        tta: tta,
      );
    }

    final counts = <String, int>{};
    for (final f in frames) {
      counts[f.label] = (counts[f.label] ?? 0) + 1;
    }
    final winner =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final agreeing = frames.where((f) => f.label == winner).toList();
    final meanConfidence =
        agreeing.map((f) => f.confidence).reduce((a, b) => a + b) /
            agreeing.length;
    final meanEntropy =
        agreeing.map((f) => f.entropy).reduce((a, b) => a + b) /
            agreeing.length;

    // Consensus rule: for a 5-frame live burst, at least 3 must agree.
    final bool lacksConsensus =
        !tta && frames.length >= 5 && agreeing.length < 3;

    // Confidence rule: mean confidence of agreeing frames must reach threshold.
    final bool lowConfidence = meanConfidence < abstainBelow;

    // Entropy rule: if the model is nearly uniform across classes, abstain.
    // Normalised entropy > 0.45 means no class is strongly favoured.
    final bool highEntropy = meanEntropy > maxEntropy;

    final bool isInconclusive = lowConfidence || lacksConsensus || highEntropy;

    if (isInconclusive) {
      return ScreeningResult(
        condition: 'Inconclusive',
        conditionLabel: 'Inconclusive',
        confidence: meanConfidence,
        agreeVotes: tta ? 1 : agreeing.length,
        totalFrames: tta ? 1 : frames.length,
        urgency: Urgency.medium,
        referralText: 'Refer to veterinarian',
        protocol: null,
        imagePath: imagePath,
        heatmap: heatmap,
        inconclusive: true,
        tta: tta,
      );
    }

    final protocol = kConditionProtocols[winner];
    final isHealthy = winner.toLowerCase() == 'healthy';
    final conditionLabel = protocol?.conditionLabel ??
        (isHealthy ? 'Dermatologically normal' : 'Unrecognised');
    final urgency = protocol?.urgency ??
        (isHealthy ? Urgency.low : Urgency.medium);
    final referralText = protocol?.referralText ??
        (isHealthy ? 'Continue monitoring' : 'Refer to veterinarian');

    return ScreeningResult(
      condition: winner,
      conditionLabel: conditionLabel,
      confidence: meanConfidence,
      agreeVotes: tta ? 1 : agreeing.length,
      totalFrames: tta ? 1 : frames.length,
      urgency: urgency,
      referralText: referralText,
      protocol: protocol,
      imagePath: imagePath,
      heatmap: heatmap,
      inconclusive: false,
      tta: tta,
    );
  }
}
