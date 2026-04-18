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

  testWidgets('collapses and draws checkmark, then calls onMorphComplete',
      (tester) async {
    await tester.pumpWidget(const _Host());

    final state = tester.state<_HostState>(find.byType(_Host));
    state.setState(() => state.saving = true);
    await tester.pump(const Duration(milliseconds: 220));

    state.setState(() => state.savedOnce = true);
    await tester.pump(const Duration(milliseconds: 270));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 270));

    expect(state.completeCount, 1);
  });
}
