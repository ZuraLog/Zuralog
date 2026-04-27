import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/feedback/z_toast.dart';

void main() {
  testWidgets('ZToast displays with default 3.5s duration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ZToast.success(context, 'Hello'),
            child: const Text('Show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Hello'), findsOneWidget);
    // After 4 seconds the default (3.5s display) should be gone
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('ZToast respects custom displayDuration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ZToast.success(
              context,
              'Custom',
              displayDuration: const Duration(seconds: 10),
            ),
            child: const Text('Show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Custom'), findsOneWidget);
    // At 4s (default dismiss time), custom should still be showing
    await tester.pump(const Duration(milliseconds: 4200));
    expect(find.text('Custom'), findsOneWidget);
  });
}
