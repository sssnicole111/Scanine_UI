import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanine_app/models/guidance_data.dart';
import 'package:scanine_app/models/screening_result.dart';
import 'package:scanine_app/screens/result_screen.dart';

void main() {
  ScreeningResult createResult(String condition) {
    final protocol = kConditionProtocols[condition]!;
    return ScreeningResult(
      condition: condition,
      conditionLabel: protocol.conditionLabel,
      confidence: 0.92,
      agreeVotes: 5,
      totalFrames: 5,
      urgency: protocol.urgency,
      referralText: protocol.referralText,
      protocol: protocol,
    );
  }

  group('ResultScreen Guidance Layout Tests', () {
    testWidgets(
        'All 12 combinations (3 conditions x 4 tabs) at 360dp width (1.0x & 1.3x) with identical fixed height 252.0',
        (tester) async {
      final conditions = ['FAD', 'Ringworm', 'Hotspot'];
      final tabs = ["Do's", "Don't", "Monitor", "Home care"];

      for (final scale in [1.0, 1.3]) {
        for (final condition in conditions) {
          tester.view.physicalSize = const Size(360 * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'InstrumentSans'),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: ResultScreen(
                  key: ValueKey('$condition-$scale'),
                  result: createResult(condition),
                ),
              ),
            ),
          );

          // Both accordions collapsed by default
          expect(find.text('First-response guidance'), findsOneWidget);

          // Scroll down to and expand "First-response guidance"
          await tester.ensureVisible(find.text('First-response guidance'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('First-response guidance'));
          await tester.pumpAndSettle();

          // Scroll up so the guidance container is well clear of the sticky action footer
          await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
          await tester.pumpAndSettle();

          // Expected fixed container height = (800 * 0.315).clamp(240.0, 300.0) = 252.0
          const expectedHeight = 252.0;

          for (final tab in tabs) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();

            // Assert container height is identical
            final containerFinder = find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == expectedHeight,
            );
            expect(containerFinder, findsOneWidget,
                reason:
                    'Container height must be $expectedHeight for $condition $tab at $scale scale');

            // Assert no RenderFlex overflow in any combination
            expect(tester.takeException(), isNull,
                reason: 'Overflow occurred in $condition tab $tab at $scale');
          }
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Short screen (360x640 at 1.3x text scale) at 240dp minimum height',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      // At 640dp height: (640 * 0.315).clamp(240.0, 300.0) = 201.6 clamped to 240.0
      const expectedHeight = 240.0;
      final containerFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == expectedHeight,
      );
      expect(containerFinder, findsOneWidget);

      // Verify all 4 tabs in the vertical rail fit without overflow
      expect(find.text("Do's"), findsOneWidget);
      expect(find.text("Don't"), findsOneWidget);
      expect(find.text('Monitor'), findsOneWidget);
      expect(find.text('Home care'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Tall screen (360x960 at 1.0x text scale) at 300dp maximum height',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 960 * 2);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 960),
              textScaler: TextScaler.linear(1.0),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      // At 960dp height: (960 * 0.315).clamp(240.0, 300.0) = 302.4 clamped to 300.0
      const expectedHeight = 300.0;
      final containerFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == expectedHeight,
      );
      expect(containerFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Equal-height test: IntrinsicWidth rail wrapper, divider, and steps pane each match container height',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.0),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      // Scroll up so guidance is in view
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      const expectedHeight = 252.0;

      // 1. Measure IntrinsicWidth wrapper around the rail (not inner Column)
      final railWrapperFinder = find.byType(IntrinsicWidth);
      expect(railWrapperFinder, findsOneWidget);
      expect(tester.getSize(railWrapperFinder).height, expectedHeight);

      // 2. Measure the 1px hairline divider
      final dividerFinder = find.byKey(const Key('guidance_divider'));
      expect(dividerFinder, findsOneWidget);
      expect(tester.getSize(dividerFinder).height, expectedHeight);

      // 3. Measure the steps pane
      final stepsPaneFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_GuidanceStepsPane',
      );
      expect(stepsPaneFinder, findsOneWidget);
      expect(tester.getSize(stepsPaneFinder).height, expectedHeight);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Rail tabs: 4 tabs at 38dp stacked with no gaps and first tab alignment at 1.0x text scale within 2dp',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;

      final hotspotProtocol = kConditionProtocols['Hotspot']!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.0),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Consecutive tab tops are exactly 38dp apart (no gaps)
      final dosTop = tester.getTopLeft(find.text("Do's")).dy;
      final dontTop = tester.getTopLeft(find.text("Don't")).dy;
      final monitorTop = tester.getTopLeft(find.text('Monitor')).dy;
      final homeCareTop = tester.getTopLeft(find.text('Home care')).dy;

      expect(dontTop - dosTop, closeTo(38.0, 1.0));
      expect(monitorTop - dontTop, closeTo(38.0, 1.0));
      expect(homeCareTop - monitorTop, closeTo(38.0, 1.0));

      // At 1.0x text scale, first tab text and first step action line align within 2dp
      final firstActionText = hotspotProtocol.startHere.first.action;
      final actionTop = tester.getTopLeft(find.text(firstActionText)).dy;
      expect((dosTop - actionTop).abs(), lessThanOrEqualTo(2.0));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Scroll affordance fade, scrolling to end, and scroll reset on tab change',
        (tester) async {
      tester.view.physicalSize = const Size(800 * 2, 960 * 2);
      tester.view.devicePixelRatio = 2.0;

      final hotspotProtocol = kConditionProtocols['Hotspot']!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 960),
              textScaler: TextScaler.linear(1.0),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      // Scroll up so the guidance container is well in view
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // 1. "Do's" is selected by default on first open and overflows the compact container.
      // Bottom fade must be present before scrolling.
      expect(find.byKey(const Key('guidance_bottom_fade')), findsOneWidget);

      // Scroll to the bottom of "Do's"
      final firstDosAction = hotspotProtocol.startHere.first.action;
      await tester.drag(find.text(firstDosAction), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Scrolled to end: fade affordance must be absent.
      expect(find.byKey(const Key('guidance_bottom_fade')), findsNothing);

      // 2. Switch to "Monitor" (15 steps, overflows container).
      await tester.tap(find.text('Monitor'));
      await tester.pumpAndSettle();

      // Bottom fade must be present on first open before user scrolls
      expect(find.byKey(const Key('guidance_bottom_fade')), findsOneWidget);

      // First step is visible
      final firstMonitorAction = hotspotProtocol.monitoring.first.action;
      final lastMonitorAction = hotspotProtocol.monitoring.last.action;
      expect(find.text(firstMonitorAction), findsOneWidget);

      // 3. Scroll down to the end of the 15-step list
      await tester.drag(find.text(firstMonitorAction), const Offset(0, -1200));
      await tester.pumpAndSettle();

      // Last step is now visible
      expect(find.text(lastMonitorAction), findsOneWidget);

      // 4. Switch to "Do's" tab and then back to "Monitor" to test scroll reset
      await tester.tap(find.text("Do's"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monitor'));
      await tester.pumpAndSettle();

      // After switching back, scroll position is reset to top (first step visible again)
      expect(find.text(firstMonitorAction), findsOneWidget);
      // Fade is present again because we are back at the top
      expect(find.byKey(const Key('guidance_bottom_fade')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('No chevron icons and both action and reason are always visible',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;

      final hotspotProtocol = kConditionProtocols['Hotspot']!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'InstrumentSans'),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.0),
            ),
            child: ResultScreen(result: createResult('Hotspot')),
          ),
        ),
      );

      await tester.ensureVisible(find.text('First-response guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First-response guidance'));
      await tester.pumpAndSettle();

      // Assert NO chevron icon exists in the guidance area
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);

      // In "Do's", all 3 steps fit and both action AND reason are visible
      for (final step in hotspotProtocol.startHere) {
        expect(find.text(step.action), findsOneWidget);
        expect(find.text(step.reason), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
