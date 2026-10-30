// lib/ml/subject_check.dart
//
// Subject gate: before a photo reaches the Scanine classifier, Google ML Kit's
// on-device image labeler checks that it plausibly shows a dog. Separate from
// the Scanine model, which is not touched.
//
// Three verdicts, so a close-up the labeler can't place is never blocked:
//   dog     – "Dog" label at or above [SubjectThresholds.dogKeep]
//   notDog  – no confident "Dog", and a clear non-dog scene/object label
//   unsure  – anything else (continue as normal)
//
// Thresholds from the on-phone evaluation (854 dog / 148 not-dog photos):
// 1.5% of dog photos rejected, 49% of not-dog photos caught, 5.5% unsure.

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

enum SubjectVerdict { dog, notDog, unsure }

class SubjectThresholds {
  const SubjectThresholds({this.dogKeep = 0.50, this.otherReject = 0.55});

  /// "Dog" confidence at or above this passes outright.
  final double dogKeep;

  /// A [nonDogLabels] label at or above this (with no confident "Dog") rejects.
  final double otherReject;
}

/// ML Kit labels that clearly mean "not a dog's skin". "Cat" and "Fur" are
/// deliberately absent: ML Kit gives both to close-ups of dog fur.
const Set<String> nonDogLabels = {
  'Food', 'Tableware', 'Cuisine', 'Meal', 'Fast food', 'Vegetable', 'Fruit',
  'Dessert', 'Drink', 'Room', 'Desk', 'Chair', 'Couch', 'Bed', 'Building',
  'Skyscraper', 'Flower', 'Plant', 'Musical instrument', 'Event', 'Leisure',
  'Fun', 'Toy', 'Vehicle', 'Car', 'Bicycle', 'Motorcycle', 'Train', 'Boat',
  'Airplane', 'Smile', 'Selfie', 'Sports', 'Stadium', 'Television', 'Computer',
  'Screenshot', 'Cool', 'Crowd', 'Team', 'Sky', 'Bridge', 'Road', 'Shelf',
  'Kitchen', 'Bathroom', 'Pizza', 'Cake', 'Bread', 'Christmas', 'Umbrella',
  'Surfboard', 'Skateboard', 'Skiing',
};

class SubjectAssessment {
  const SubjectAssessment(this.verdict, {this.dogScore = 0, this.otherLabel});

  final SubjectVerdict verdict;
  final double dogScore;

  /// The non-dog label behind a [SubjectVerdict.notDog], for logging.
  final String? otherLabel;

  bool get isNotDog => verdict == SubjectVerdict.notDog;

  static const SubjectAssessment unknown = SubjectAssessment(SubjectVerdict.unsure);

  /// Pure decision from (label, confidence) pairs; kept separate for tests.
  static SubjectAssessment decide(
    Iterable<(String, double)> labels, {
    SubjectThresholds thresholds = const SubjectThresholds(),
  }) {
    var dog = 0.0;
    String? other;
    var otherScore = 0.0;
    for (final (label, score) in labels) {
      if (label == 'Dog' && score > dog) dog = score;
      if (nonDogLabels.contains(label) && score > otherScore) {
        other = label;
        otherScore = score;
      }
    }
    if (dog >= thresholds.dogKeep) {
      return SubjectAssessment(SubjectVerdict.dog, dogScore: dog);
    }
    if (otherScore >= thresholds.otherReject) {
      return SubjectAssessment(SubjectVerdict.notDog, dogScore: dog, otherLabel: other);
    }
    return SubjectAssessment(SubjectVerdict.unsure, dogScore: dog);
  }
}

class SubjectCheck {
  SubjectCheck._();

  static ImageLabeler? _labeler;

  /// Labels the photo at [path]. Any failure returns "unsure", so the check
  /// can never block a screening on its own error.
  static Future<SubjectAssessment> assessFile(
    String path, {
    SubjectThresholds thresholds = const SubjectThresholds(),
  }) async {
    try {
      final labeler = _labeler ??= ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.3),
      );
      final labels = await labeler.processImage(InputImage.fromFilePath(path));
      return SubjectAssessment.decide(
        labels.map((l) => (l.label, l.confidence)),
        thresholds: thresholds,
      );
    } catch (_) {
      return SubjectAssessment.unknown;
    }
  }
}
