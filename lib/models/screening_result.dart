import 'dart:typed_data';

import '../ml/classifier.dart';

// First-response guidance, ported from FIRST_RESPONSE_GUIDANCE in the PWA's
// CameraScreen.jsx. Keyed by the model's label so the two classes still in
// training slot straight in when they ship.

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
  'Normal': _Guidance(
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

  /// Majority vote across the captured frames, with a confidence-abstention
  /// gate — the same decision rule the PWA uses.
  factory ScreeningResult.fromFrames({
    required List<FrameResult> frames,
    required String imagePath,
    Uint8List? heatmap,
    double abstainBelow = 0.60,
    bool tta = false,
  }) {
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
      inconclusive: meanConfidence < abstainBelow,
      tta: tta,
    );
  }
}

/// The two classes the current binary model cannot yet report.
class PendingClass {
  final String name;
  final String description;
  const PendingClass(this.name, this.description);
}

const kPendingClasses = <PendingClass>[
  PendingClass(
    'Flea Allergy Dermatitis',
    'FAD — itch and hair loss from flea bite hypersensitivity',
  ),
  PendingClass(
    'Hotspot',
    'Acute moist dermatitis',
  ),
];
