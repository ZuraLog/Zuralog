import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/layout/app_shell.dart'
    show BottomNavClusterForTest, LogPillButtonForTest;

const _logPillKey = Key('bottom-nav-log-pill');

void main() {
  group('_LogPillButton', () {
    testWidgets('icon rotates to 45° when isOpen flips true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _LogPillHarness(initialOpen: false)),
      );

      // Closed state: rotation is 0.
      final rotationAtStart = _readRotationTurns(tester);
      expect(rotationAtStart, 0.0);

      // Flip to open.
      final state = tester.state<_LogPillHarnessState>(
        find.byType(_LogPillHarness),
      );
      state.setOpen(true);
      // Pattern overlay animates continuously — can't use pumpAndSettle.
      // 210ms > rotation duration (200ms) guarantees the rotation completes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));

      final rotationAtOpen = _readRotationTurns(tester);
      expect(rotationAtOpen, closeTo(0.125, 0.001));

      // Flip back to closed.
      state.setOpen(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));

      final rotationAtClose = _readRotationTurns(tester);
      expect(rotationAtClose, closeTo(0.0, 0.001));
    });
  });

  group('_BottomNavCluster', () {
    testWidgets('renders both pills with the log pill keyed',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: BottomNavClusterForTest(
                currentIndex: 0,
                onDestinationSelected: (_) {},
                isLogSheetOpen: false,
                onLogPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('bottom-nav-log-pill')), findsOneWidget);
      // The 3 tab labels from the frosted nav bar are present.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);

      // Assert the log pill and frosted nav live in the same Row —
      // this is the whole point of the cluster.
      final rowFinder = find.ancestor(
        of: find.byKey(const Key('bottom-nav-log-pill')),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsWidgets);
    });

    testWidgets('tapping the log pill invokes onLogPressed', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: BottomNavClusterForTest(
                currentIndex: 0,
                onDestinationSelected: (_) {},
                isLogSheetOpen: false,
                onLogPressed: () => tapCount++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('bottom-nav-log-pill')));
      await tester.pump();

      expect(tapCount, 1);
    });
  });
}

double _readRotationTurns(WidgetTester tester) {
  final rotation = tester.widget<RotationTransition>(
    find.descendant(
      of: find.byKey(_logPillKey),
      matching: find.byType(RotationTransition),
    ),
  );
  return rotation.turns.value;
}

class _LogPillHarness extends StatefulWidget {
  const _LogPillHarness({required this.initialOpen});
  final bool initialOpen;
  @override
  State<_LogPillHarness> createState() => _LogPillHarnessState();
}

class _LogPillHarnessState extends State<_LogPillHarness> {
  late bool _open = widget.initialOpen;
  void setOpen(bool v) => setState(() => _open = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: LogPillButtonForTest(
        isOpen: _open,
        onTap: () {},
      ),
    );
  }
}
