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
}
