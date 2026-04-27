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

  testWidgets('cloud icon hidden when sync status is none', (tester) async {
    await tester.pumpWidget(_buildPanel(
      supplements: [const SupplementEntry(id: 's1', name: 'Vitamin D')],
      syncStatus: SupplementSyncStatus.none,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
  });

  testWidgets('cloud upload icon shown when pending', (tester) async {
    await tester.pumpWidget(_buildPanel(
      supplements: [const SupplementEntry(id: 's1', name: 'Vitamin D')],
      syncStatus: SupplementSyncStatus.pending,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('cloud done icon shown when synced', (tester) async {
    await tester.pumpWidget(_buildPanel(
      supplements: [const SupplementEntry(id: 's1', name: 'Vitamin D')],
      syncStatus: SupplementSyncStatus.synced,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('uncheck shows confirmation dialog not undo toast', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Magnesium', timing: 'evening'),
    ];
    final todayLog = [
      const SupplementTodayLogEntry(supplementId: 's1', logId: 'log1'),
    ];
    await tester.pumpWidget(_buildPanel(supplements: supplements, todayLog: todayLog));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Magnesium'));
    await tester.pump();
    // Dialog should appear
    expect(find.text('Remove log entry?'), findsOneWidget);
    expect(find.text('Remove entry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancelling uncheck dialog keeps supplement as taken', (tester) async {
    final supplements = [
      const SupplementEntry(id: 's1', name: 'Magnesium', timing: 'evening'),
    ];
    final todayLog = [
      const SupplementTodayLogEntry(supplementId: 's1', logId: 'log1'),
    ];
    await tester.pumpWidget(_buildPanel(supplements: supplements, todayLog: todayLog));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Magnesium'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Should still show taken (check_circle)
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('one-off log link visible below supplement list', (tester) async {
    await tester.pumpWidget(_buildPanel(
      supplements: [const SupplementEntry(id: 's1', name: 'Vitamin D')],
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+ Log something extra today'), findsOneWidget);
  });

  testWidgets('tapping one-off link expands inline form', (tester) async {
    await tester.pumpWidget(_buildPanel(
      supplements: [const SupplementEntry(id: 's1', name: 'Vitamin D')],
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('+ Log something extra today'));
    await tester.pump();
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Log today'), findsOneWidget);
  });

  testWidgets('insights icon is present in panel header', (tester) async {
    await tester.pumpWidget(_buildPanel(supplements: []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
  });
}
