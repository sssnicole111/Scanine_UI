import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/screens/home_screen.dart';
import 'package:scanine_app/widgets/scanine_mark.dart';

void main() {
  testWidgets('Home screen renders the screening card and brand mark',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.byType(ScanineMark), findsOneWidget);
    expect(find.text('start screening'), findsOneWidget);
  });
}
