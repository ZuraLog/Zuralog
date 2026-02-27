// test/features/integrations/presentation/widgets/compatible_apps_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/domain/compatible_apps_registry.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_apps_section.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: CustomScrollView(slivers: [child]),
        ),
      );

  group('CompatibleAppsSection', () {
    testWidgets('shows header with total app count', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppsSection()));
      final count = CompatibleAppsRegistry.apps.length;
      expect(find.text('Compatible Apps ($count)'), findsOneWidget);
    });

    testWidgets('starts collapsed (no tiles visible)', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppsSection()));
      // No app names should be visible when collapsed
      expect(find.text('Oura Ring'), findsNothing);
    });

    testWidgets('expands when tapped', (tester) async {
      await tester.pumpWidget(wrap(const CompatibleAppsSection()));
      await tester.tap(find.text('Compatible Apps (${CompatibleAppsRegistry.apps.length})'));
      await tester.pumpAndSettle();
      // At least one tile should now be visible
      expect(find.text('Oura Ring'), findsOneWidget);
    });

    testWidgets('filters list by searchQuery', (tester) async {
      await tester.pumpWidget(
        wrap(const CompatibleAppsSection(searchQuery: 'Nike')),
      );
      // Should show only Nike Run Club, and the section should be auto-expanded
      expect(find.text('Compatible Apps (1)'), findsOneWidget);
      expect(find.text('Nike Run Club'), findsOneWidget);
    });

    testWidgets('auto-expands when searchQuery is set', (tester) async {
      // Start collapsed with no query
      await tester.pumpWidget(wrap(const CompatibleAppsSection()));
      // Initially collapsed
      expect(find.text('Nike Run Club'), findsNothing);
      // Rebuild with an active search query — should auto-expand
      await tester.pumpWidget(
        wrap(const CompatibleAppsSection(searchQuery: 'Nike')),
      );
      await tester.pumpAndSettle();
      // Should auto-expand and show Nike Run Club
      expect(find.text('Nike Run Club'), findsOneWidget);
    });
  });
}
