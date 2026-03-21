/// Zuralog — MetricDetailScreen widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/data/presentation/metric_detail_screen.dart';

Widget _wrapWidget(Widget child) => MaterialApp(
  theme: ThemeData.light(),
  home: Scaffold(body: child),
);

void main() {
  group('formatMetricIdForDisplay helper', () {
    test('converts snake_case to Title Case', () {
      expect(formatMetricIdForDisplay('steps'), 'Steps');
      expect(formatMetricIdForDisplay('heart_rate_resting'), 'Heart Rate Resting');
      expect(formatMetricIdForDisplay('sleep_duration'), 'Sleep Duration');
    });
  });

  group('MetricDetailSkeleton', () {
    testWidgets('renders AppShimmer', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(const MetricDetailSkeleton(metricId: 'steps')),
      );
      await tester.pump();
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('renders without error for multi-word metricId', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(
          const MetricDetailSkeleton(metricId: 'heart_rate_resting'),
        ),
      );
      await tester.pump();
      expect(find.byType(MetricDetailSkeleton), findsOneWidget);
    });
  });

  group('MetricDetailErrorBody', () {
    testWidgets('renders retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrapWidget(MetricDetailErrorBody(onRetry: () => retried = true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('renders cloud_off icon', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(MetricDetailErrorBody(onRetry: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('MetricDetailEmptyState', () {
    testWidgets('empty data: renders chart icon and Try 30 days button',
        (tester) async {
      var changed = false;
      await tester.pumpWidget(
        _wrapWidget(MetricDetailEmptyState(
          pointCount: 0,
          onExpandRange: () => changed = true,
        )),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
      expect(find.text('Try 30 days'), findsOneWidget);
      await tester.tap(find.text('Try 30 days'));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('single data point: renders radio button icon and CTA',
        (tester) async {
      await tester.pumpWidget(
        _wrapWidget(MetricDetailEmptyState(
          pointCount: 1,
          onExpandRange: () {},
        )),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(find.text('Try 30 days'), findsOneWidget);
    });
  });
}
