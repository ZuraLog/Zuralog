import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;
import 'package:zuralog/shared/widgets/cards/z_ai_breakdown_card.dart';

void main() {
  testWidgets('ZAiBreakdownCard renders headline + section rows',
      (tester) async {
    final summary = const AllDataSummary(
      headline: 'A strong, well-recovered day.',
      body: [],
      sections: [
        AllDataSummarySection(
          category: HealthCategory.sleep,
          primaryMetricId: 'deep_sleep',
          name: 'Sleep recovered well',
          elaboration: 'Deep sleep was above your normal.',
          deltaLabel: '↑ 12%',
        ),
      ],
      referenceCount: 1,
    );
    AllDataSummarySection? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZAiBreakdownCard(
          summary: summary,
          onSectionTap: (s) => tapped = s,
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('A strong, well-recovered day.'), findsOneWidget);
    expect(find.text('Sleep recovered well'), findsOneWidget);
    expect(find.text('↑ 12%'), findsOneWidget);

    await tester.tap(find.text('Sleep recovered well'));
    await tester.pumpAndSettle();
    expect(tapped?.primaryMetricId, 'deep_sleep');
  });

  testWidgets('ZAiBreakdownCard fires onClose when × is tapped', (tester) async {
    var closed = false;
    final summary = const AllDataSummary(
      headline: 'Calm',
      body: [],
      sections: [],
      referenceCount: 0,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZAiBreakdownCard(
          summary: summary,
          onSectionTap: (_) {},
          onClose: () => closed = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(closed, true);
  });
}
