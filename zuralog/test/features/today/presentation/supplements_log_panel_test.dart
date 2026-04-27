import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_supplements_log_panel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget _buildPanel({
    List<SupplementEntry> supplements = const [],
    List<SupplementTodayLogEntry> todayLog = const [],
    SupplementSyncStatus syncStatus = SupplementSyncStatus.none,
    VoidCallback? onSave,
    VoidCallback? onBack,
  }) {
    return ProviderScope(
      overrides: [
        supplementsListProvider.overrideWith((_) async => supplements),
        supplementsTodayLogProvider.overrideWith((_) async => todayLog),
        supplementsSyncStatusProvider.overrideWith((_) async => syncStatus),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ZSupplementsLogPanel(
            onSave: onSave ?? () {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows empty state when no supplements', (tester) async {
    await tester.pumpWidget(_buildPanel(supplements: []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No stack yet'), findsOneWidget);
    expect(find.text('Set up my stack'), findsOneWidget);
  });

  testWidgets('shows supplement rows when stack is loaded', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D', timing: 'morning'),
      const SupplementEntry(id: 's2', name: 'Omega 3', timing: 'evening'),
    ];
    await tester.pumpWidget(_buildPanel(supplements: supplements));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Omega 3'), findsOneWidget);
  });

  testWidgets('marks supplement as taken when tapped', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D', timing: 'morning'),
    ];
    await tester.pumpWidget(_buildPanel(supplements: supplements));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Vitamin D'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('shows taken count in subtitle', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Vitamin D'),
      const SupplementEntry(id: 's2', name: 'Magnesium'),
    ];
    final todayLog = [
      const SupplementTodayLogEntry(supplementId: 's1', logId: 'log1'),
    ];
    await tester.pumpWidget(_buildPanel(supplements: supplements, todayLog: todayLog));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('1 of 2'), findsOneWidget);
  });
}
