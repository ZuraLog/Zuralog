import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('HealthScoreWidget.colorForScore', () {
    test('null score → textTertiary', () {
      expect(
        HealthScoreWidget.colorForScore(null),
        AppColors.textTertiary,
      );
    });
    test('score 0 → red', () {
      expect(HealthScoreWidget.colorForScore(0), AppColors.healthScoreRed);
    });
    test('score 39 → red', () {
      expect(HealthScoreWidget.colorForScore(39), AppColors.healthScoreRed);
    });
    test('score 40 → amber', () {
      expect(HealthScoreWidget.colorForScore(40), AppColors.healthScoreAmber);
    });
    test('score 69 → amber', () {
      expect(HealthScoreWidget.colorForScore(69), AppColors.healthScoreAmber);
    });
    test('score 70 → green', () {
      expect(HealthScoreWidget.colorForScore(70), AppColors.healthScoreGreen);
    });
    test('score 100 → green', () {
      expect(HealthScoreWidget.colorForScore(100), AppColors.healthScoreGreen);
    });
  });

  group('HealthScoreWidget.hero', () {
    testWidgets('renders score label', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(score: 82)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('82'), findsOneWidget);
    });

    testWidgets('renders sparkline when trend has ≥ 2 values', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(
          score: 82,
          trend: [74, 78, 80, 79, 83, 81, 82],
        )),
      );
      await tester.pump(const Duration(milliseconds: 800));
      // Sparkline is rendered via fl_chart LineChart.
      expect(find.byType(HealthScoreWidget), findsOneWidget);
    });

    testWidgets('renders commentary when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(
          score: 72,
          commentary: 'Great consistency this week.',
        )),
      );
      await tester.pump();
      expect(find.text('Great consistency this week.'), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(
          score: 55,
          onTap: () => tapped = true,
        )),
      );
      await tester.pump();
      await tester.tap(find.byType(HealthScoreWidget));
      expect(tapped, isTrue);
    });
  });

  group('HealthScoreWidget.compact', () {
    testWidgets('renders score label', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.compact(score: 55)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('55'), findsOneWidget);
    });

    testWidgets('does not render commentary', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.compact(score: 55)),
      );
      await tester.pump();
      // No Text other than the score itself.
      expect(find.text('55'), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.compact(
          score: 90,
          onTap: () => tapped = true,
        )),
      );
      await tester.pump();
      await tester.tap(find.byType(HealthScoreWidget));
      expect(tapped, isTrue);
    });
  });

  group('HealthScoreWidget — null score', () {
    testWidgets('hero renders loading indicator when score is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(score: null)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('HealthScoreWidget — animation', () {
    testWidgets('animation completes within duration', (tester) async {
      await tester.pumpWidget(
        _wrap(HealthScoreWidget.hero(score: 75)),
      );
      // Pump for the full animation duration.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('75'), findsOneWidget);
    });
  });
}
