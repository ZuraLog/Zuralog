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
            selectedLevel: 1,
            onChanged: (_) {},
          ),
        ),
      );

      // All 5 AnimatedContainers must be present.
      expect(find.byType(AnimatedContainer), findsNWidgets(5));

      // The first container (index 0, level 1) should be selected — its
      // BoxDecoration color is non-null (tinted), while the others use the
      // surface color (also non-null but different).  We verify by checking
      // that the selected container's decoration differs from the last one's.
      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();

      final selectedDecoration =
          containers.first.decoration as BoxDecoration;
      final unselectedDecoration =
          containers.last.decoration as BoxDecoration;

      expect(selectedDecoration.color, isNotNull);
      expect(unselectedDecoration.color, isNotNull);
      expect(selectedDecoration.color, isNot(equals(unselectedDecoration.color)));
    });

    testWidgets('reversed: true — icon order flips but level emission stays 1–5', (tester) async {
      int? tappedLevel;
      await tester.pumpWidget(
        _themed(
          ZSentimentSelector(
            reversed: true,
            selectedLevel: null,
            onChanged: (level) => tappedLevel = level,
          ),
        ),
      );

      // 5 icons must render.
      expect(find.byType(GestureDetector), findsNWidgets(5));

      // Tap the leftmost icon (position 0) — should still emit level 1.
      final detectors = find.byType(GestureDetector);
      await tester.tap(detectors.at(0));
      await tester.pump();

      expect(tappedLevel, 1);
    });
  });
}
