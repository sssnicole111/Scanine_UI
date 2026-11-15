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
//             human skin, a clear non-dog scene/object, knitted fabric, or a
//             photo mostly in strong green/blue/purple (fabric, posters)
//   unsure  – anything else (continue as normal)
//
// Thresholds from the on-phone evaluation: 854 dog photos, 148 COCO not-dog
// photos, 226 computer-lab objects/fabrics and 120 human skin close-ups
// (SCIN). 2.2% of dog photos rejected (all of them Healthy), 51% of the COCO
// photos, 73% of the lab photos and 88% of the human skin caught.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, instantiateImageCodec;
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

/// Strong green, blue or purple: no dog's skin or coat is this colour, but
/// fabric, posters and screens often are. A photo with more than
/// [vividReject] of its pixels in these colours, and no confident "Dog",
/// rejects. On the 854 dataset dog photos, every one above 0.30 also has
/// "Dog" at 0.5 or more (dogs on grass), so none is blocked.
const double vividReject = 0.30;

/// True for one pixel in strong green/blue/purple: OpenCV HSV hue 35-155
/// (70°-310°), saturation above 90 and value above 50 (0-255 scales).
bool isVividPixel(int r, int g, int b) {
  final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  if (mx <= 50) return false;
  final d = mx - mn;
  if (d * 255 <= 90 * mx) return false;
  double h;
  if (mx == r) {
    h = 60.0 * (g - b) / d;
  } else if (mx == g) {
    h = 120.0 + 60.0 * (b - r) / d;
  } else {
    h = 240.0 + 60.0 * (r - g) / d;
  }
  if (h < 0) h += 360;
  return h >= 70 && h <= 310;
}

/// Share of vivid pixels in an RGBA buffer, sampling every [step]th pixel.
double vividShareRgba(Uint8List rgba, int width, int height, {int step = 2}) {
  var n = 0, hit = 0;
  for (var y = 0; y < height; y += step) {
    for (var x = 0; x < width; x += step) {
      final i = (y * width + x) * 4;
      n++;
      if (isVividPixel(rgba[i], rgba[i + 1], rgba[i + 2])) hit++;
    }
  }
  return n == 0 ? 0 : hit / n;
}

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
    double vivid = 0,
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

    if (vivid > vividReject) return reject('Vivid colour');

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
  }) async =>
      _assess(
        InputImage.fromFilePath(path),
        thresholds,
        vivid: await _vividShareOfFile(path),
      );

  /// Vivid-colour share of a photo file, decoded small. 0 on any failure.
  static Future<double> _vividShareOfFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 224);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return 0;
        return vividShareRgba(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          image.width,
          image.height,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      return 0;
    }
  }

  /// Vivid-colour share of an NV21 preview frame (Y plane, then interleaved
  /// V/U at half resolution), sampling every 8th pixel.
  static double _vividShareOfNv21(Uint8List bytes, int width, int height) {
    final ySize = width * height;
    if (bytes.length < ySize + ySize ~/ 2) return 0;
    var n = 0, hit = 0;
    for (var y = 0; y < height; y += 8) {
      for (var x = 0; x < width; x += 8) {
        final yy = bytes[y * width + x];
        final uv = ySize + (y >> 1) * width + (x & ~1);
        final v = bytes[uv] - 128, u = bytes[uv + 1] - 128;
        int c(double f) => f < 0 ? 0 : (f > 255 ? 255 : f.round());
        final r = c(yy + 1.402 * v);
        final g = c(yy - 0.344 * u - 0.714 * v);
        final b = c(yy + 1.772 * u);
        n++;
        if (isVividPixel(r, g, b)) hit++;
      }
    }
    return n == 0 ? 0 : hit / n;
  }

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
      vivid: plane.bytesPerRow == frame.width
          ? _vividShareOfNv21(plane.bytes, frame.width, frame.height)
          : 0,
    );
  }

  static Future<SubjectAssessment> _assess(
    InputImage image,
    SubjectThresholds thresholds, {
    double vivid = 0,
  }) async {
    try {
      final labels = await _shared.processImage(image);
      return SubjectAssessment.decide(
        labels.map((l) => (l.label, l.confidence)),
        thresholds: thresholds,
        vivid: vivid,
      );
    } catch (_) {
      return SubjectAssessment.unknown;
    }
  }
}
