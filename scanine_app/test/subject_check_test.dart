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
}
