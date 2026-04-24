import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

void main() {
  testWidgets('MuscleHighlightDiagram.zones builds without throwing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MuscleHighlightDiagram.zones(
            zones: {
              MuscleGroup.shoulders: Color(0xFFFF375F),
              MuscleGroup.quads: Color(0xFF30D158),
            },
            strokeless: true,
          ),
        ),
      ),
    );
    expect(find.byType(MuscleHighlightDiagram), findsOneWidget);
  });

  testWidgets('MuscleHighlightDiagram.zones supports onlyFront / onlyBack',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            MuscleHighlightDiagram.zones(
              zones: {MuscleGroup.chest: Color(0xFFFF9F0A)},
              onlyFront: true,
            ),
            MuscleHighlightDiagram.zones(
              zones: {MuscleGroup.back: Color(0xFFFF9F0A)},
              onlyBack: true,
            ),
          ]),
        ),
      ),
    );
    expect(find.byType(MuscleHighlightDiagram), findsNWidgets(2));
  });
}
