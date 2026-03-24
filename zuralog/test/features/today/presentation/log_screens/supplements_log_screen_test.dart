import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_log_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

class _MockTodayRepository extends Mock implements TodayRepositoryInterface {}

final _fakeSupplements = [
  const SupplementEntry(id: 'sup-1', name: 'Vitamin D', dose: '1000 IU'),
  const SupplementEntry(id: 'sup-2', name: 'Magnesium', timing: 'evening'),
];

ProviderContainer _container({List<SupplementEntry>? supplements}) {
  final mock = _MockTodayRepository();
  return ProviderContainer(overrides: [
    supplementsListProvider
        .overrideWith((ref) async => supplements ?? _fakeSupplements),
    todayRepositoryProvider.overrideWithValue(mock),
  ]);
}

Widget _wrap(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    );

void main() {
  group('SupplementsLogScreen', () {
    testWidgets('shows empty state prompt when no supplements saved',
        (tester) async {
      final container = _container(supplements: []);
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      expect(
        find.text('Add your supplements and medications to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('shows supplement list when supplements exist', (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      expect(find.text('Vitamin D'), findsOneWidget);
      expect(find.text('1000 IU'), findsOneWidget);
    });

    testWidgets('Save button disabled when no supplements selected',
        (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Save button enabled after tapping a supplement',
        (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsLogScreen(), container));
      await tester.pumpAndSettle();

      // Tap the first supplement's trailing toggle circle (AnimatedContainer inside GestureDetector)
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pump();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(btn.onPressed, isNotNull);
    });
  });
}
