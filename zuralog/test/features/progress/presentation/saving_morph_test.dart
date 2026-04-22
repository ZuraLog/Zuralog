import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/progress/presentation/widgets/saving_morph.dart';

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool saving = false;
  bool savedOnce = false;
  int completeCount = 0;

  void triggerSaving(bool value) => setState(() => saving = value);
  void triggerSavedOnce(bool value) => setState(() => savedOnce = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SavingMorph(
            label: 'Save Entry',
            onPressed: () {},
            isSaving: saving,
            savedOnce: savedOnce,
            onMorphComplete: () => completeCount++,
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('renders the label in idle state', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(find.text('Save Entry'), findsOneWidget);
  });

  testWidgets('morphs through collapse → check → fade → completion',
      (tester) async {
    await tester.pumpWidget(const _Host());
    final state = tester.state<_HostState>(find.byType(_Host));

    // Trigger collapsing.
    state.triggerSaving(true);
    await tester.pump();                                      // start animation
    await tester.pump(const Duration(milliseconds: 100));    // mid-collapse
    // At mid-collapse, the checkmark CustomPaint should not be in the tree
    // (only the check phase renders our _CheckPainter).
    final midCollapsePaintCount = tester.widgetList(find.byType(CustomPaint)).length;

    await tester.pump(const Duration(milliseconds: 150));    // finish collapse (200ms total)

    // Trigger checking.
    state.triggerSavedOnce(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));    // finish check (250ms)

    // Checkmark painter is now in the tree — more CustomPaints than during collapse.
    expect(
      tester.widgetList(find.byType(CustomPaint)).length,
      greaterThan(midCollapsePaintCount),
    );
    expect(state.completeCount, 0); // not fired yet — still in hold

    // Wait the 300ms hold + 260ms dismiss.
    await tester.pump(const Duration(milliseconds: 310));    // past hold
    await tester.pump(const Duration(milliseconds: 260));    // past dismiss

    // Completion callback fired exactly once.
    expect(state.completeCount, 1);
  });
}
