import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/models/screening_result.dart';
import 'package:scanine_app/screens/result_screen.dart';

void main() {
  testWidgets('a photo with no dog never shows a condition or heatmap',
      (WidgetTester tester) async {
    final result = ScreeningResult.noDog(imagePath: '/missing.jpg');
    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    expect(find.text('No dog found'), findsOneWidget);
    expect(find.textContaining('a dog'), findsWidgets);
    expect(find.text('Choose another photo'), findsOneWidget);
    expect(find.text('Heatmap not available for this scan'), findsOneWidget);
    for (final condition in ['ringworm', 'a hot spot', 'flea allergy', 'Heatmap']) {
      expect(find.text(condition), findsNothing, reason: condition);
    }
    expect(find.text('Refer to veterinarian'), findsNothing);
  });
}
