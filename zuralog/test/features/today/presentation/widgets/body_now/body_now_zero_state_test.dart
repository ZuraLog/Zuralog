import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_zero_state.dart';

void main() {
  testWidgets('BodyNowZeroState renders welcoming copy + connect CTA',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BodyNowZeroState(onConnect: () => tapped++),
        ),
      ),
    );
    expect(find.textContaining("meet your body"), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    expect(tapped, 1);
  });
}
