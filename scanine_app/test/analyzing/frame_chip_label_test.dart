import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/screens/analyzing_screen.dart';

void main() {
  test('a Healthy frame reads "No signs", not a health claim', () {
    expect(frameChipLabel('Healthy'), 'No signs');
  });

  test('condition names match the result screen', () {
    expect(frameChipLabel('Hotspot'), 'Hot spot');
    expect(frameChipLabel('Ringworm'), 'Ringworm');
    expect(frameChipLabel('FAD'), 'FAD');
  });
}
