import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/shared/widgets/cards/z_insight_card.dart';

InsightCard _makeInsight({bool isRead = false}) => InsightCard(
      id: 'test-id',
      title: 'Test Insight Title',
      summary: 'Summary text here',
      type: InsightType.trend,
      category: 'Sleep',
      isRead: isRead,
      priorityScore: 0.8,
      createdAt: DateTime(2026, 3, 16, 8, 0),
    );

void main() {
  group('ZInsightCard', () {
    testWidgets('renders title and summary', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ZInsightCard(
                insight: _makeInsight(),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Test Insight Title'), findsOneWidget);
      expect(find.text('Summary text here'), findsOneWidget);
    });

    testWidgets('shows category chip when rendered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ZInsightCard(
                insight: _makeInsight(isRead: false),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      // Unread card renders the category label chip.
      expect(find.text('Sleep'), findsOneWidget);
      // Title is rendered.
      expect(find.text('Test Insight Title'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ZInsightCard(
                insight: _makeInsight(),
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ZInsightCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
