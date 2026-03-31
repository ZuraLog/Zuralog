import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ghost_banner.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows ghost icon and banner text', (tester) async {
    await tester.pumpWidget(_wrap(
      CoachGhostBanner(onExit: () {}),
    ));
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    expect(find.text('Ghost Mode — nothing is being saved'), findsOneWidget);
  });

  testWidgets('calls onExit when Exit is tapped', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(
      CoachGhostBanner(onExit: () => called = true),
    ));
    await tester.tap(find.text('Exit'));
    await tester.pump();
    expect(called, isTrue);
  });
}
