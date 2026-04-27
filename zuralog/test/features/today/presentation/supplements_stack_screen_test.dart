import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_stack_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget buildScreen({List<SupplementEntry> supplements = const [], bool openAddForm = false}) {
    return ProviderScope(
      overrides: [
        supplementsListProvider.overrideWith((_) async => supplements),
      ],
      child: MaterialApp(
        home: SupplementsStackScreen(openAddFormOnStart: openAddForm),
      ),
    );
  }

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
}
