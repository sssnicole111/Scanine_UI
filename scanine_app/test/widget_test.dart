import 'package:flutter_test/flutter_test.dart';

import 'package:scanine_app/main.dart';

void main() {
  testWidgets('Home screen renders the screening card',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ScanineApp());

    expect(find.text('Scanine'), findsOneWidget);
    expect(find.text('Start screening'), findsOneWidget);
  });
}
