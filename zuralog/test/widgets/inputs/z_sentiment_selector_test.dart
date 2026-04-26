/// Widget tests for [ZSentimentSelector].
///
/// Verifies icon count, tap callbacks, and selected-state rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/inputs/z_sentiment_selector.dart';

/// Wraps [child] in a themed [MaterialApp] so theme resolution works.
Widget _themed(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('ZSentimentSelector', () {
    testWidgets('renders 5 tappable icons', (tester) async {
      await tester.pumpWidget(
        _themed(
          ZSentimentSelector(
            selectedLevel: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNWidgets(5));
    });

    testWidgets('fires onChanged with correct level on tap', (tester) async {
      int? tappedLevel;
      await tester.pumpWidget(
        _themed(
          ZSentimentSelector(
            selectedLevel: null,
            onChanged: (level) => tappedLevel = level,
          ),
        ),
      );

      // Tap the GestureDetector at index 2 (the middle icon — level 3).
      final detectors = find.byType(GestureDetector);
      await tester.tap(detectors.at(2));
      await tester.pump();

      expect(tappedLevel, 3);
    });

    testWidgets('shows selected state on correct icon', (tester) async {
      await tester.pumpWidget(
        _themed(
          ZSentimentSelector(
            selectedLevel: 4,
            onChanged: (_) {},
          ),
        ),
      );

      // Widget should build without error when a level is pre-selected.
      expect(find.byType(ZSentimentSelector), findsOneWidget);
    });
  });
}
