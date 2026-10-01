/// Ported from FIRST_RESPONSE_GUIDANCE in the PWA's CameraScreen.jsx.
///
/// DEMO BUILD: nothing here runs a model. The result is canned so the
/// screen flow can be demonstrated. When the TFLite model is wired in,
/// only `ScreeningResult.demo()` gets replaced — this table stays.

enum Urgency { high, medium, low }

class ScreeningResult {
  final String condition;
  final String conditionLabel;
  final double confidence; // 0..1
  final int agreeVotes;
  final int totalFrames;
  final Urgency urgency;
  final String referralText;
  final List<String> guidance;
  final String? imagePath;

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
  });

  int get confidencePercent => (confidence * 100).round();

  /// Placeholder result used until the model is wired in.
  factory ScreeningResult.demo({String? imagePath, int totalFrames = 5}) {
    return ScreeningResult(
      condition: 'Ringworm',
      conditionLabel: 'Dermatophytosis',
      confidence: 0.95,
      agreeVotes: 4,
      totalFrames: totalFrames,
      urgency: Urgency.high,
      referralText: 'Refer to veterinarian',
      imagePath: imagePath,
      guidance: const [
        'Isolate the dog from other pets and children to limit zoonotic spread.',
        'Wash hands after handling the animal, its bedding, or grooming tools.',
        'Avoid sharing crates or bedding until a vet clears the animal.',
        'Schedule a veterinary visit to confirm and begin antifungal treatment.',
      ],
    );
  }
}

/// The two classes the current model cannot yet report.
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
