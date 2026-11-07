// lib/ml/subject_check.dart
//
// Subject gate: before a photo reaches the Scanine classifier, Google ML Kit's
// on-device image labeler checks that it plausibly shows a dog. Separate from
// the Scanine model, which is not touched.
//
// Three verdicts, so a close-up the labeler can't place is never blocked:
//   dog     – "Dog" label at or above [SubjectThresholds.dogKeep], unless the
//             photo is clearly a human face
//   notDog  – a human face; or, with no confident "Dog": human body or bare
//             human skin, a clear non-dog scene/object, or knitted fabric
//   unsure  – anything else (continue as normal)
//
// Thresholds from the on-phone evaluation: 854 dog photos, 148 COCO not-dog
// photos, 226 computer-lab objects/fabrics and 120 human skin close-ups
// (SCIN). 2.2% of dog photos rejected (all of them Healthy), 51% of the COCO
// photos, 73% of the lab photos and 88% of the human skin caught.

import 'dart:ui' show Size;

import 'package:camera/camera.dart';
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
/// deliberately absent: ML Kit gives both to close-ups of dog fur. Clothing
/// words ("Jacket", "Jeans", "Textile") are absent too: ML Kit uses them for
/// dog coats.
const Set<String> nonDogLabels = {
  'Food', 'Tableware', 'Cuisine', 'Meal', 'Fast food', 'Vegetable', 'Fruit',
  'Dessert', 'Drink', 'Room', 'Desk', 'Chair', 'Couch', 'Bed', 'Building',
  'Skyscraper', 'Flower', 'Plant', 'Musical instrument', 'Event', 'Leisure',
  'Fun', 'Toy', 'Vehicle', 'Car', 'Bicycle', 'Motorcycle', 'Train', 'Boat',
  'Airplane', 'Smile', 'Selfie', 'Sports', 'Stadium', 'Television', 'Computer',
  'Screenshot', 'Cool', 'Crowd', 'Team', 'Sky', 'Bridge', 'Road', 'Shelf',
  'Kitchen', 'Bathroom', 'Pizza', 'Cake', 'Bread', 'Christmas', 'Umbrella',
  'Surfboard', 'Skateboard', 'Skiing',
  // Computer-lab objects (no dataset dog photo carries these at 0.55).
  'Bag', 'Handbag', 'Leather', 'Mobile phone', 'Poster', 'Paper', 'Metal',
  'Tie', 'Flag', 'Wheel', 'Bumper', 'Helmet', 'Goggles', 'Jersey', 'Shorts',
};

/// Human face labels. At or above [faceReject] they reject even when ML Kit
/// also says "Dog" (a face can reach "Dog" 0.6); no dataset dog photo does.
const Set<String> faceLabels = {'Selfie', 'Smile', 'Mouth'};
const double faceReject = 0.80;

/// Human body labels: reject at [bodyReject] when "Dog" isn't confident.
const Set<String> bodyLabels = {
  'Hand',
  'Nail',
  'Finger',
  'Tattoo',
  'Muscle',
  'Foot',
  'Toe',
};
const double bodyReject = 0.70;

/// Bare human skin: "Skin" at [bareSkin] with "Flesh" at [bareFlesh], no
/// confident "Dog" and no coat label. A dog lesion close-up almost always
/// also gets "Dog" or a [coatLabels] label, so it still passes.
const double bareSkin = 0.85;
const double bareFlesh = 0.50;

/// Labels that point to an animal coat; any at [coatSeen] keeps a "Skin"
/// photo from counting as bare human skin.
const Set<String> coatLabels = {
  'Fur',
  'Hair',
  'Wool',
  'Whiskers',
  'Beard',
  'Cat',
  'Pet',
  'Horse',
};
const double coatSeen = 0.55;

/// Knitted fabric (towels, sweaters). Only rejects when "Dog" is below
/// [knitMaxDog], since ML Kit sometimes calls a woolly coat "Knitting".
const Set<String> knitLabels = {'Knitting', 'Wool', 'Crochet', 'Needlework'};
const double knitReject = 0.60;
const double knitMaxDog = 0.30;

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
    final scores = <String, double>{};
    for (final (label, score) in labels) {
      if (score > (scores[label] ?? 0)) scores[label] = score;
    }
    double of(String label) => scores[label] ?? 0;

    /// The strongest label from [set] at or above [min], or null.
    String? strongest(Set<String> set, double min) {
      String? best;
      for (final l in set) {
        if (of(l) >= min && (best == null || of(l) > of(best))) best = l;
      }
      return best;
    }

    final dog = of('Dog');
    SubjectAssessment reject(String label) => SubjectAssessment(
      SubjectVerdict.notDog,
      dogScore: dog,
      otherLabel: label,
    );

    // A clear human face rejects even next to a "Dog" label.
    final face = strongest(faceLabels, faceReject);
    if (face != null) return reject(face);

    if (dog >= thresholds.dogKeep) {
      return SubjectAssessment(SubjectVerdict.dog, dogScore: dog);
    }

    final body = strongest(bodyLabels, bodyReject);
    if (body != null) return reject(body);

    if (of('Skin') >= bareSkin &&
        of('Flesh') >= bareFlesh &&
        strongest(coatLabels, coatSeen) == null) {
      return reject('Skin');
    }

    final other = strongest(nonDogLabels, thresholds.otherReject);
    if (other != null) return reject(other);

    if (dog < knitMaxDog) {
      final knit = strongest(knitLabels, knitReject);
      if (knit != null) return reject(knit);
    }

    return SubjectAssessment(SubjectVerdict.unsure, dogScore: dog);
  }
}

class SubjectCheck {
  SubjectCheck._();

  static ImageLabeler? _labeler;

  static ImageLabeler get _shared => _labeler ??= ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.3),
      );

  /// Labels the photo at [path]. Any failure returns "unsure", so the check
  /// can never block a screening on its own error.
  static Future<SubjectAssessment> assessFile(
    String path, {
    SubjectThresholds thresholds = const SubjectThresholds(),
  }) =>
      _assess(InputImage.fromFilePath(path), thresholds);

  /// Labels a live camera preview frame (NV21, as the camera screen requests)
  /// for the "no dog in view" hint while aiming. Other frame formats, and any
  /// failure, return "unsure", so the hint never shows by mistake.
  static Future<SubjectAssessment> assessCameraFrame(
    CameraImage frame, {
    required int sensorOrientation,
    SubjectThresholds thresholds = const SubjectThresholds(),
  }) async {
    if (frame.format.group != ImageFormatGroup.nv21 || frame.planes.length != 1) {
      return SubjectAssessment.unknown;
    }
    final plane = frame.planes.first;
    return _assess(
      InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(sensorOrientation) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
      thresholds,
    );
  }

  static Future<SubjectAssessment> _assess(
    InputImage image,
    SubjectThresholds thresholds,
  ) async {
    try {
      final labels = await _shared.processImage(image);
      return SubjectAssessment.decide(
        labels.map((l) => (l.label, l.confidence)),
        thresholds: thresholds,
      );
    } catch (_) {
      return SubjectAssessment.unknown;
    }
  }
}
