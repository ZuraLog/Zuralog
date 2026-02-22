// Life Logger Edge Agent — Smoke Test.
//
// Basic test to verify the app boots without errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LifeLoggerApp()));

    expect(find.text('ZuraLog'), findsOneWidget);
  });
}
