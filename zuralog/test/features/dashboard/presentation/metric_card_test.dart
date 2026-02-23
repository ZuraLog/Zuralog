/// Zuralog Dashboard — Metric Card Widget Tests.
///
/// Verifies [MetricCard] renders value, unit, title, and icon correctly, and
/// that the trend direction icon and [onTap] callback behave as expected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/trend_sparkline.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Wraps [widget] in a bounded [MaterialApp] scaffold so [MetricCard]'s
/// intrinsic sizing resolves correctly.
Widget _wrap(Widget widget) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 240,
        child: widget,
      ),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MetricCard — rendering', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Sleep',
            value: '7.5',
            unit: 'hrs',
            icon: Icons.bedtime_rounded,
            accentColor: AppColors.secondaryLight,
            trendData: const [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the value text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Steps',
            value: '8,432',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            accentColor: AppColors.primary,
            trendData: const [7000, 7500, 8000, 7800, 8200, 8400, 8432],
          ),
        ),
      );
      expect(find.text('8,432'), findsOneWidget);
    });

    testWidgets('renders the unit text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Steps',
            value: '8,432',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            accentColor: AppColors.primary,
            trendData: const [7000, 7500, 8000, 7800, 8200, 8400, 8432],
          ),
        ),
      );
      expect(find.text('steps'), findsOneWidget);
    });

    testWidgets('renders the title text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Steps',
            value: '8,432',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            accentColor: AppColors.primary,
            trendData: const [7000, 7500, 8000, 7800, 8200, 8400, 8432],
          ),
        ),
      );
      expect(find.text('Steps'), findsOneWidget);
    });

    testWidgets('renders the metric icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Sleep',
            value: '7.5',
            unit: 'hrs',
            icon: Icons.bedtime_rounded,
            accentColor: AppColors.secondaryLight,
            trendData: const [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
          ),
        ),
      );
      expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
    });

    testWidgets('renders a TrendSparkline', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Sleep',
            value: '7.5',
            unit: 'hrs',
            icon: Icons.bedtime_rounded,
            accentColor: AppColors.secondaryLight,
            trendData: const [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
          ),
        ),
      );
      expect(find.byType(TrendSparkline), findsOneWidget);
    });
  });

  // ── Trend direction icons ─────────────────────────────────────────────────────

  group('MetricCard — trend direction', () {
    testWidgets('shows trending_up icon when trend goes up', (tester) async {
      // First value 1000, last value 2000 → +100% → trending up.
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Steps',
            value: '2,000',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            accentColor: AppColors.primary,
            trendData: const [1000, 1200, 1400, 1600, 1700, 1900, 2000],
          ),
        ),
      );
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('shows trending_down icon when trend goes down', (tester) async {
      // First value 2000, last value 1000 → -50% → trending down.
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Steps',
            value: '1,000',
            unit: 'steps',
            icon: Icons.directions_walk_rounded,
            accentColor: AppColors.primary,
            trendData: const [2000, 1800, 1600, 1400, 1200, 1100, 1000],
          ),
        ),
      );
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('shows trending_flat when trend is ~same', (tester) async {
      // Values within ±2% → flat.
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Sleep',
            value: '7.5',
            unit: 'hrs',
            icon: Icons.bedtime_rounded,
            accentColor: AppColors.secondaryLight,
            trendData: const [7.5, 7.4, 7.6, 7.5, 7.4, 7.5, 7.5],
          ),
        ),
      );
      expect(find.byIcon(Icons.trending_flat), findsOneWidget);
    });
  });

  // ── onTap ─────────────────────────────────────────────────────────────────────

  group('MetricCard — onTap', () {
    testWidgets('invokes onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          MetricCard(
            title: 'Sleep',
            value: '7.5',
            unit: 'hrs',
            icon: Icons.bedtime_rounded,
            accentColor: AppColors.secondaryLight,
            trendData: const [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(MetricCard));
      expect(tapped, isTrue);
    });
  });
}
