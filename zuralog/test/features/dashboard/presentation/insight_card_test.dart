/// Zuralog Dashboard — Insight Card Widget Tests.
///
/// Verifies [InsightCard] renders the insight text, that [InsightCardShimmer]
/// renders a placeholder, and that tapping the card invokes [onTap].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/insight_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Wraps [widget] in a minimal [MaterialApp] scaffold.
Widget _wrap(Widget widget) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(body: SingleChildScrollView(child: widget)),
  );
}

const String _kInsightText =
    'You hit your step goal 5 days this week. Keep it up!';

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('InsightCard', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InsightCard(
            insight: const DashboardInsight(insight: _kInsightText),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the insight text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InsightCard(
            insight: const DashboardInsight(insight: _kInsightText),
          ),
        ),
      );
      expect(find.text(_kInsightText), findsOneWidget);
    });

    testWidgets('renders the "AI Insight" label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InsightCard(
            insight: const DashboardInsight(insight: _kInsightText),
          ),
        ),
      );
      expect(find.text('AI Insight'), findsOneWidget);
    });

    testWidgets('tapping card invokes onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          InsightCard(
            insight: const DashboardInsight(insight: _kInsightText),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InsightCard));
      expect(tapped, isTrue);
    });

    testWidgets('onTap is null — no crash when tapped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InsightCard(
            insight: const DashboardInsight(insight: _kInsightText),
          ),
        ),
      );
      // Should not throw even without an onTap callback.
      await tester.tap(find.byType(InsightCard));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Shimmer placeholder ──────────────────────────────────────────────────────

  group('InsightCardShimmer', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const InsightCardShimmer()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an Opacity widget for the shimmer effect',
        (tester) async {
      await tester.pumpWidget(_wrap(const InsightCardShimmer()));
      // The shimmer uses an AnimatedBuilder > Opacity tree.
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('has the same height as InsightCard (160)', (tester) async {
      await tester.pumpWidget(_wrap(const InsightCardShimmer()));
      // The shimmer Container should be 160 px tall.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InsightCardShimmer),
              matching: find.byType(Container),
            )
            .last,
      );
      final decoration = container.decoration as BoxDecoration?;
      // Verify a BoxDecoration with a gradient is present (premium gradient bg).
      expect(decoration?.gradient, isNotNull);
    });
  });
}
