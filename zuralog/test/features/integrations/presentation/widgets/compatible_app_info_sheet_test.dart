// test/features/integrations/presentation/widgets/compatible_app_info_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/domain/compatible_app.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_app_info_sheet.dart';

void main() {
  const testApp = CompatibleApp(
    id: 'oura',
    name: 'Oura Ring',
    supportsHealthKit: true,
    supportsHealthConnect: true,
    brandColor: 0xFF514689,
    description: 'Sleep, readiness, and activity tracking.',
    dataFlowExplanation:
        'Oura Ring syncs sleep stages, heart rate, HRV, and activity to Apple Health and Health Connect.',
    storeUrl: 'https://apps.apple.com/app/oura/id1043837948',
  );

  const testAppWithDeepLink = CompatibleApp(
    id: 'cal_ai',
    name: 'Cal AI',
    supportsHealthKit: true,
    supportsHealthConnect: true,
    brandColor: 0xFF4CAF50,
    description: 'AI-powered nutrition scanning.',
    dataFlowExplanation: 'Cal AI writes nutrition data.',
    deepLinkUrl: 'calai://camera',
  );

  const testAppNoLinks = CompatibleApp(
    id: 'test',
    name: 'Test App',
    supportsHealthKit: true,
    supportsHealthConnect: false,
    brandColor: 0xFF000000,
    description: 'Test.',
    dataFlowExplanation: 'Test flow.',
  );

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  group('CompatibleAppInfoSheet', () {
    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppInfoSheet(app: testApp)));
      expect(find.text('Oura Ring'), findsOneWidget);
    });

    testWidgets('displays data flow explanation', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppInfoSheet(app: testApp)));
      expect(
        find.textContaining('Oura Ring syncs sleep stages'),
        findsOneWidget,
      );
    });

    testWidgets('shows "How data flows" section header', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppInfoSheet(app: testApp)));
      expect(find.text('How data flows'), findsOneWidget);
    });

    testWidgets('shows Open in Store button when storeUrl is provided', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const CompatibleAppInfoSheet(app: testApp)));
      expect(find.text('Open in Store'), findsOneWidget);
    });

    testWidgets('hides Open in Store button when storeUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const CompatibleAppInfoSheet(app: testAppNoLinks)),
      );
      expect(find.text('Open in Store'), findsNothing);
    });

    testWidgets('shows Open App button when deepLinkUrl is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const CompatibleAppInfoSheet(app: testAppWithDeepLink)),
      );
      expect(find.text('Open App'), findsOneWidget);
    });

    testWidgets('hides Open App button when deepLinkUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const CompatibleAppInfoSheet(app: testApp)));
      expect(find.text('Open App'), findsNothing);
    });
  });
}
