import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integrations_search_bar.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  group('IntegrationsSearchBar', () {
    testWidgets('renders TextField with search hint', (tester) async {
      await tester.pumpWidget(
        wrap(IntegrationsSearchBar(onChanged: (_) {})),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search integrations...'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? captured;
      await tester.pumpWidget(
        wrap(IntegrationsSearchBar(onChanged: (v) => captured = v)),
      );
      await tester.enterText(find.byType(TextField), 'Nike');
      expect(captured, 'Nike');
    });

    testWidgets('shows clear button when text is not empty', (tester) async {
      await tester.pumpWidget(
        wrap(IntegrationsSearchBar(onChanged: (_) {})),
      );
      await tester.enterText(find.byType(TextField), 'Oura');
      await tester.pump();
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('clear button resets to empty and calls onChanged', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(
        wrap(IntegrationsSearchBar(onChanged: values.add)),
      );
      await tester.enterText(find.byType(TextField), 'Nike');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();
      expect(values.last, '');
      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });
  });
}
