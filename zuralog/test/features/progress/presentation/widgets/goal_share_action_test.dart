library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_share_action.dart';

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: c),
    );

void main() {
  testWidgets('renders the share label', (tester) async {
    await tester.pumpWidget(_wrap(const GoalShareAction()));
    expect(find.text('Share progress'), findsOneWidget);
  });

  testWidgets('shows snackbar on tap', (tester) async {
    await tester.pumpWidget(_wrap(const GoalShareAction()));
    await tester.tap(find.text('Share progress'));
    await tester.pump();
    expect(find.textContaining('coming soon'), findsOneWidget);
  });
}
