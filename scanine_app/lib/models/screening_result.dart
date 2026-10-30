import 'dart:typed_data';

import '../ml/classifier.dart';

// First-response guidance, ported from FIRST_RESPONSE_GUIDANCE in the PWA's
// CameraScreen.jsx. Keyed by the model's label so every class slots straight
// in now that the 4-class model has shipped.

enum Urgency { high, medium, low }

class _Guidance {
  final String conditionLabel;
  final Urgency urgency;
  final String referralText;
  final List<String> lines;
  const _Guidance(
      this.conditionLabel, this.urgency, this.referralText, this.lines);
}

const _guidance = <String, _Guidance>{
  'Ringworm': _Guidance(
    'Dermatophytosis',
    Urgency.high,
    'Refer to veterinarian',
    [
      'Isolate the dog from other pets and children to limit zoonotic spread.',
      'Wash hands after handling the animal, its bedding, or grooming tools.',
      'Avoid sharing crates or bedding until a vet clears the animal.',
      'Schedule a veterinary visit to confirm and begin antifungal treatment.',
    ],
  ),
  'Hotspot': _Guidance(
    'Hotspot (acute moist dermatitis)',
    Urgency.high,
    'Refer to veterinarian',
    [
      'Carefully trim or clip fur around the lesion to allow airflow.',
      'Gently clean the affected area with a mild antiseptic solution.',
      'Prevent the dog from licking or scratching — use an e-collar if needed.',
      'Schedule a veterinary visit for topical or oral treatment.',
    ],
  ),
  'FAD': _Guidance(
    'Flea allergy dermatitis',
    Urgency.medium,
    'Refer to veterinarian',
    [
      'Check the dog thoroughly for fleas, especially around the tail base.',
      'Apply a vet-recommended flea preventative immediately.',
      'Treat the home environment (bedding, carpets) for flea eggs and larvae.',
      'Schedule a veterinary visit if itching persists or worsens.',
    ],
  ),
  'Healthy': _Guidance(
    'Dermatologically normal',
    Urgency.low,
    'Continue monitoring',
    [
      'No signs consistent with the trained conditions were detected.',
      'Keep monitoring the area for changes over the next few days.',
      'Rescan if redness, hair loss or scaling appears.',
    ],
  ),
};

/// Guidance shown when the result is inconclusive / low-confidence.
const _inconclusiveGuidance = _Guidance(
  'Inconclusive',
  Urgency.medium,
  'Refer to veterinarian',
  [
    'The scan could not confidently identify a condition.',
    'This may happen with non-canine subjects, poor lighting, or motion blur.',
    'Ensure the camera is focused on the dog\'s skin, not fur or surroundings.',
    'Retake the scan with the affected area clearly visible and well-lit.',
    'If symptoms are present, consult a veterinarian directly.',
  ],
);

class ScreeningResult {
  final String condition;
  final String conditionLabel;
  final double confidence;
  final int agreeVotes;
  final int totalFrames;
  final Urgency urgency;
  final String referralText;
  final List<String> guidance;
  final String? imagePath;
  final Uint8List? heatmap;
  final bool inconclusive;

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
    required this.guidance,
    this.imagePath,
    this.heatmap,
    this.inconclusive = false,
    this.tta = false,
  });

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
  /// With model 20261029_1757 the 0.70 threshold gives 95.5% selective
  /// accuracy on the test set while answering 92.7% of images
  /// (threshold_table.csv). The notebook's automatic suggestion for this run
  /// was 0.40 (answer everything); 0.70 is kept so uncertain photos are flagged.
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
        conditionLabel: _inconclusiveGuidance.conditionLabel,
        confidence: 0.0,
        agreeVotes: 0,
        totalFrames: 0,
        urgency: _inconclusiveGuidance.urgency,
        referralText: _inconclusiveGuidance.referralText,
        guidance: _inconclusiveGuidance.lines,
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
        conditionLabel: _inconclusiveGuidance.conditionLabel,
        confidence: meanConfidence,
        agreeVotes: agreeing.length,
        totalFrames: frames.length,
        urgency: _inconclusiveGuidance.urgency,
        referralText: _inconclusiveGuidance.referralText,
        guidance: _inconclusiveGuidance.lines,
        imagePath: imagePath,
        heatmap: heatmap,
        inconclusive: true,
        tta: tta,
      );
    }

    final g = _guidance[winner] ??
        const _Guidance('Unrecognised', Urgency.medium,
            'Refer to veterinarian', ['Consult a veterinarian.']);

    return ScreeningResult(
      condition: winner,
      conditionLabel: g.conditionLabel,
      confidence: meanConfidence,
      agreeVotes: agreeing.length,
      totalFrames: frames.length,
      urgency: g.urgency,
      referralText: g.referralText,
      guidance: g.lines,
      imagePath: imagePath,
      heatmap: heatmap,
      inconclusive: false,
      tta: tta,
    );
  }
}
