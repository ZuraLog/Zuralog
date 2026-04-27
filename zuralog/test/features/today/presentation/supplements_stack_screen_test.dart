import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/today/data/mock_today_repository.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/domain/supplement_conflict.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_stack_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget _buildScreen({List<SupplementEntry> supplements = const [], bool openAddForm = false}) {
    return ProviderScope(
      overrides: [
        todayRepositoryProvider.overrideWithValue(const MockTodayRepository()),
        supplementsListProvider.overrideWith((_) async => supplements),
      ],
      child: MaterialApp(
        home: SupplementsStackScreen(openAddFormOnStart: openAddForm),
      ),
    );
  }

  // Keep the original name as an alias so existing tests compile unchanged.
  Widget buildScreen({List<SupplementEntry> supplements = const [], bool openAddForm = false}) =>
      _buildScreen(supplements: supplements, openAddForm: openAddForm);

  testWidgets('shows empty state when no supplements', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No supplements yet'), findsOneWidget);
    expect(find.text('Add supplement or med'), findsOneWidget);
  });

  testWidgets('shows supplement rows when stack is loaded', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D', timing: 'morning'),
      const SupplementEntry(id: 's2', name: 'Omega 3', timing: 'evening'),
    ];
    await tester.pumpWidget(buildScreen(supplements: supplements));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Omega 3'), findsOneWidget);
  });

  testWidgets('tapping Add opens the add form with Name field', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('add form shows timing options', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Anytime'), findsOneWidget);
  });

  testWidgets('add form shows unit options', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('mg'), findsOneWidget);
    expect(find.text('IU'), findsOneWidget);
  });

  testWidgets('openAddFormOnStart opens form immediately', (tester) async {
    await tester.pumpWidget(buildScreen(openAddForm: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('each supplement row shows supplement name', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Iron', doseAmount: 18, doseUnit: 'mg'),
    ];
    await tester.pumpWidget(buildScreen(supplements: supplements));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Iron'), findsOneWidget);
    // Dose label should appear in the row subtitle
    expect(find.textContaining('18'), findsOneWidget);
  });

  testWidgets('Scan label button is visible in the add form', (tester) async {
    await tester.pumpWidget(buildScreen(supplements: []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Scan label'), findsOneWidget);
  });

  testWidgets('conflict warning appears after typing a duplicate supplement name', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D', timing: 'morning'),
    ];
    await tester.pumpWidget(_buildScreen(supplements: supplements));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Open the add form
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Type a duplicate name into the Name field (first TextField)
    await tester.enterText(find.byType(TextField).first, 'Vitamin D');
    await tester.pump(const Duration(milliseconds: 900)); // past debounce (800ms)
    await tester.pump(const Duration(milliseconds: 300));
    // Warning card should be visible
    expect(find.text('Already in your stack'), findsOneWidget);
    expect(find.text('Add anyway'), findsOneWidget);
    expect(find.text('Adjust dose'), findsOneWidget);
  });

  testWidgets('tapping Add anyway hides the conflict warning', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D', timing: 'morning'),
    ];
    await tester.pumpWidget(_buildScreen(supplements: supplements));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, 'Vitamin D');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add anyway'), findsOneWidget);
    await tester.tap(find.text('Add anyway'));
    await tester.pump();
    expect(find.text('Add anyway'), findsNothing);
  });

  testWidgets('timing tip appears after selecting a timing option', (tester) async {
    // MockTodayRepository returns 'Take in the morning for best absorption.'
    await tester.pumpWidget(_buildScreen(supplements: []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open the Add form
    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Fill in a supplement name so the tip fetch is triggered
    await tester.enterText(find.byType(TextField).first, 'Vitamin D');
    await tester.pump();

    // Ensure the Morning option is visible before tapping
    await tester.ensureVisible(find.text('Morning'));
    await tester.pump();

    // Tap the Morning timing option
    await tester.tap(find.text('Morning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // wait for mock delay
    await tester.pump();

    expect(find.text('Take in the morning for best absorption.'), findsOneWidget);
  });

  testWidgets('timing tip can be dismissed', (tester) async {
    await tester.pumpWidget(_buildScreen(supplements: []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Add supplement or med'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).first, 'Vitamin D');
    await tester.pump();

    // Ensure the Morning option is visible before tapping
    await tester.ensureVisible(find.text('Morning'));
    await tester.pump();

    await tester.tap(find.text('Morning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Take in the morning for best absorption.'), findsOneWidget);

    // Tap the dismiss (X) button on the ZAlertBanner
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Take in the morning for best absorption.'), findsNothing);
  });
}
