import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplements_stack_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

class _MockTodayRepository extends Mock implements TodayRepositoryInterface {}

final _fakeSupplements = [
  const SupplementEntry(id: 'sup-1', name: 'Vitamin D', dose: '1000 IU'),
  const SupplementEntry(id: 'sup-2', name: 'Magnesium', timing: 'evening'),
];

ProviderContainer _container({List<SupplementEntry>? supplements}) {
  final mock = _MockTodayRepository();
  when(() => mock.updateSupplementsList(any())).thenAnswer((_) async => []);
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SupplementsStackScreen', () {
    testWidgets('shows empty state prompt when no supplements saved',
        (tester) async {
      final container = _container(supplements: []);
      await tester.pumpWidget(_wrap(const SupplementsStackScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('No supplements yet'),
        findsOneWidget,
      );
    });

    testWidgets('shows supplement list when supplements exist', (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsStackScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Vitamin D'), findsOneWidget);
      expect(find.text('Magnesium'), findsOneWidget);
    });

    testWidgets('shows add supplement button', (tester) async {
      final container = _container();
      await tester.pumpWidget(_wrap(const SupplementsStackScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Add supplement or med'), findsOneWidget);
    });

    testWidgets('tapping add opens the add form', (tester) async {
      final container = _container(supplements: []);
      await tester.pumpWidget(_wrap(const SupplementsStackScreen(), container));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Tap the add button
      await tester.tap(find.text('Add supplement or med'));
      await tester.pump();
      // The form should be visible — look for a typical form field label
      expect(find.text('Name'), findsAtLeastNWidgets(1));
    });
  });
}
