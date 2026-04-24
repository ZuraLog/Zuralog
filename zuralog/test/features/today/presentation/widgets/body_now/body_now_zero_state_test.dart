import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_zero_state.dart';

void main() {
  testWidgets('BodyNowZeroState renders welcoming copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BodyNowZeroState(),
        ),
      ),
    );
    expect(find.textContaining("meet your body"), findsOneWidget);
    // Connect CTA lives in the coach strip below the hero, not in the
    // zero state itself — avoids duplicating the call-to-action.
    expect(find.text('Connect'), findsNothing);
  });
}
