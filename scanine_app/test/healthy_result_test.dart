import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/models/screening_result.dart';
import 'package:scanine_app/screens/result_screen.dart';

ScreeningResult healthyResult() => ScreeningResult(
      condition: 'Healthy',
      conditionLabel: 'Dermatologically normal',
      confidence: 0.95,
      agreeVotes: 5,
      totalFrames: 5,
      urgency: Urgency.low,
      referralText: 'Continue monitoring',
      // The model returns a Grad-CAM for every answer, healthy included.
      heatmap: Uint8List(8),
    );

void main() {
  testWidgets('healthy result names the conditions and shows no heatmap',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: healthyResult())));

    // The headline is a RichText.
    expect(
      find.textContaining('ringworm, hot spot or flea allergy dermatitis',
          findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('No signs of skin problems', findRichText: true),
        findsNothing);
    expect(find.text('No areas of concern to highlight'), findsOneWidget);
    // Plain text: no check icon, no pill behind it.
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
    expect(
      find.ancestor(
        of: find.text('No areas of concern to highlight'),
        matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration != null),
      ),
      findsNothing,
    );
    expect(find.text('Heatmap'), findsNothing);
  });

  testWidgets('inconclusive result says "Heatmap not available" in the tag',
      (WidgetTester tester) async {
    final result =
        ScreeningResult.fromFrames(frames: const [], imagePath: '/missing.jpg');
    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    expect(find.text('Heatmap not available'), findsOneWidget);
    expect(find.text('Low confidence'), findsNothing);
    // No pill on the photo any more.
    expect(find.text('Heatmap not available for this scan'), findsNothing);
  });
}
