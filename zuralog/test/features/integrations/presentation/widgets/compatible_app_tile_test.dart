// test/features/integrations/presentation/widgets/compatible_app_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zuralog/features/integrations/domain/compatible_app.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_app_tile.dart';

void main() {
  const testApp = CompatibleApp(
    id: 'oura',
    name: 'Oura Ring',
    supportsHealthKit: true,
    supportsHealthConnect: true,
    brandColor: 0xFF514689,
    description: 'Sleep, readiness, and activity.',
    dataFlowExplanation: 'Oura syncs to both platforms.',
  );

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  group('CompatibleAppTile', () {
    testWidgets('displays app name and description', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppTile(app: testApp)));
      expect(find.text('Oura Ring'), findsOneWidget);
      expect(find.text('Sleep, readiness, and activity.'), findsOneWidget);
    });

    testWidgets('shows both platform badges for dual-platform app', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const CompatibleAppTile(app: testApp)));
      expect(find.byIcon(FontAwesomeIcons.apple), findsOneWidget);
      expect(find.byIcon(Icons.android_rounded), findsOneWidget);
    });

    testWidgets('tapping opens info sheet', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppTile(app: testApp)));
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      // Info sheet should be open — "How data flows" appears
      expect(find.text('How data flows'), findsOneWidget);
    });
  });
}
