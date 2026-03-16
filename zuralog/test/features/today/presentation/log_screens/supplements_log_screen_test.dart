import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_log_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

ProviderContainer _container({List<SupplementEntry> supplements = const []}) =>
    ProviderContainer(overrides: [
      supplementsListProvider.overrideWith((ref) async => supplements),
    ]);

Widget _wrap(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(container: container, child: MaterialApp(home: child));

void main() {
  group('SupplementsLogScreen', () {
    testWidgets('shows empty state prompt when no supplements saved', (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      expect(find.text('Add your supplements and medications to get started.'), findsOneWidget);
    });

    testWidgets('shows supplement list when supplements exist', (tester) async {
      final container = _container(supplements: [
        const SupplementEntry(id: '1', name: 'Vitamin D', dose: '1000 IU'),
      ]);
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      expect(find.text('Vitamin D'), findsOneWidget);
      expect(find.text('1000 IU'), findsOneWidget);
    });

    testWidgets('Save button is always enabled', (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
      expect(btn.onPressed, isNotNull);
    });
  });
}
