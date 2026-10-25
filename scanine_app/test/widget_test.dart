import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders the screening card and wordmark',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('scanine'), findsOneWidget);
    expect(find.text('start screening'), findsOneWidget);
  });
}
