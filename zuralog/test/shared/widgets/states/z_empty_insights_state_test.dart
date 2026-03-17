import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/states/z_empty_insights_state.dart';

void main() {
  group('ZEmptyInsightsCard', () {
    testWidgets('renders headline text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZEmptyInsightsCard(
              onLogTap: () {},
              onConnectTap: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('insights'), findsWidgets);
    });

    testWidgets('calls onLogTap when log CTA tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZEmptyInsightsCard(
              onLogTap: () => tapped = true,
              onConnectTap: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Log something today'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('calls onConnectTap when connect CTA tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZEmptyInsightsCard(
              onLogTap: () {},
              onConnectTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Connect a health app'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
