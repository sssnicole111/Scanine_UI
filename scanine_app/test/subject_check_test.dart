import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/ml/subject_check.dart';

void main() {
  SubjectVerdict verdict(List<(String, double)> labels) =>
      SubjectAssessment.decide(labels).verdict;

  test('a confident Dog label passes, even with non-dog labels', () {
    expect(verdict([('Dog', 0.8), ('Food', 0.9)]), SubjectVerdict.dog);
  });

  test('no Dog and a clear non-dog label is rejected', () {
    final a = SubjectAssessment.decide([('Room', 0.7), ('Dog', 0.2)]);
    expect(a.verdict, SubjectVerdict.notDog);
    expect(a.otherLabel, 'Room');
  });

  test('Cat and Fur alone never reject (ML Kit uses them for dog fur)', () {
    expect(verdict([('Cat', 0.95), ('Fur', 0.9)]), SubjectVerdict.unsure);
  });

  test('weak labels only are unsure, not rejected', () {
    expect(verdict([('Food', 0.5), ('Dog', 0.4)]), SubjectVerdict.unsure);
    expect(verdict([]), SubjectVerdict.unsure);
  });

  test('thresholds are inclusive', () {
    expect(verdict([('Dog', 0.50)]), SubjectVerdict.dog);
    expect(verdict([('Sky', 0.55)]), SubjectVerdict.notDog);
  });

  group('human skin', () {
    test('a clear face rejects even next to a Dog label', () {
      final a = SubjectAssessment.decide([('Mouth', 0.85), ('Dog', 0.7)]);
      expect(a.verdict, SubjectVerdict.notDog);
      expect(a.otherLabel, 'Mouth');
    });

    test('hand or arm close-ups reject when Dog is not confident', () {
      expect(verdict([('Hand', 0.9), ('Skin', 0.9)]), SubjectVerdict.notDog);
      expect(verdict([('Muscle', 0.75), ('Dog', 0.4)]), SubjectVerdict.notDog);
    });

    test("an owner's hand next to a confident Dog still passes", () {
      expect(verdict([('Hand', 0.94), ('Dog', 0.8)]), SubjectVerdict.dog);
    });

    test('bare skin with flesh and no coat label rejects', () {
      final a = SubjectAssessment.decide([('Skin', 0.92), ('Flesh', 0.7)]);
      expect(a.verdict, SubjectVerdict.notDog);
      expect(a.otherLabel, 'Skin');
    });

    test('skin with a coat label (a dog lesion close-up) is not rejected', () {
      expect(
        verdict([('Skin', 0.93), ('Flesh', 0.7), ('Fur', 0.6)]),
        SubjectVerdict.unsure,
      );
      expect(verdict([('Skin', 0.93), ('Dog', 0.6)]), SubjectVerdict.dog);
    });
  });

  group('lab objects and fabrics', () {
    test('lab object words reject', () {
      expect(verdict([('Mobile phone', 0.7)]), SubjectVerdict.notDog);
      expect(verdict([('Leather', 0.6), ('Dog', 0.3)]), SubjectVerdict.notDog);
    });

    test('clothing words alone never reject (ML Kit uses them for coats)', () {
      expect(
        verdict([('Jacket', 0.9), ('Jeans', 0.8), ('Textile', 0.8)]),
        SubjectVerdict.unsure,
      );
    });

    test('knitted fabric rejects only when there is no Dog hint', () {
      expect(
        verdict([('Knitting', 0.77), ('Wool', 0.74)]),
        SubjectVerdict.notDog,
      );
      expect(verdict([('Wool', 0.8), ('Dog', 0.4)]), SubjectVerdict.unsure);
    });
  });

  group('vivid colour', () {
    test('green fabric with no confident Dog is rejected', () {
      final a = SubjectAssessment.decide(
        [('Textile', 0.8), ('Pattern', 0.7)],
        vivid: 0.6,
      );
      expect(a.verdict, SubjectVerdict.notDog);
      expect(a.otherLabel, 'Vivid colour');
    });

    test('a dog on grass still passes', () {
      final a = SubjectAssessment.decide([('Dog', 0.65)], vivid: 0.65);
      expect(a.verdict, SubjectVerdict.dog);
    });

    test('a little colour does not reject', () {
      final a = SubjectAssessment.decide([('Textile', 0.8)], vivid: 0.2);
      expect(a.verdict, SubjectVerdict.unsure);
    });

    test('pixel colours', () {
      expect(isVividPixel(90, 170, 40), isTrue); // grass green
      expect(isVividPixel(40, 80, 200), isTrue); // blue
      expect(isVividPixel(200, 120, 90), isFalse); // pink skin
      expect(isVividPixel(150, 110, 70), isFalse); // brown coat
      expect(isVividPixel(120, 130, 125), isFalse); // grey
    });
  });
}
