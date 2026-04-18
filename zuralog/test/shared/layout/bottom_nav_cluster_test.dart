import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/layout/app_shell.dart' show LogPillButtonForTest;

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
      await tester.pumpAndSettle();

      final rotationAtOpen = _readRotationTurns(tester);
      expect(rotationAtOpen, closeTo(0.125, 0.001));

      // Flip back to closed.
      state.setOpen(false);
      await tester.pumpAndSettle();

      final rotationAtClose = _readRotationTurns(tester);
      expect(rotationAtClose, closeTo(0.0, 0.001));
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
