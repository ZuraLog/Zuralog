library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_related_journal.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

Goal _g({String title = 'Weight'}) => Goal(
      id: 'g',
      userId: 'u',
      type: GoalType.custom,
      period: GoalPeriod.weekly,
      title: title,
      targetValue: 100,
      currentValue: 50,
      unit: 'units',
      startDate: '2026-04-01',
      progressHistory: const <double>[],
    );

Widget _wrap({required Widget child, required JournalPage page}) {
  return ProviderScope(
    overrides: [
      journalProvider.overrideWith((ref) async => page),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('renders nothing when no journal entries match the goal title',
      (tester) async {
    const page = JournalPage(entries: [], hasMore: false);
    await tester.pumpWidget(
      _wrap(child: GoalRelatedJournal(goal: _g()), page: page),
    );
    await tester.pump();
    expect(find.text('RELATED JOURNAL'), findsNothing);
  });
}
