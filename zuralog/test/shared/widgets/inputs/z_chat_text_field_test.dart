import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

void main() {
  testWidgets('ZChatTextField respects maxLength and fires onSubmit on send', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 10,
          placeholder: 'one sentence',
          onSubmit: (text) => submitted = text,
        ),
      ),
    ));

    // Typing more than maxLength gets truncated at the inputFormatter.
    await tester.enterText(find.byType(TextField), 'this is way too long');
    await tester.pump();
    final TextField tf = tester.widget(find.byType(TextField));
    expect(tf.controller?.text.length, lessThanOrEqualTo(10));
    expect(tf.controller?.text, 'this is wa');

    // Tapping send submits the trimmed value.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded));
    await tester.pump();
    expect(submitted, 'this is wa');
  });

  testWidgets('ZChatTextField does not submit when empty', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 10,
          placeholder: 'one sentence',
          onSubmit: (text) => submitted = text,
        ),
      ),
    ));

    // Send button should be disabled when empty.
    final sendFinder = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
    final IconButton send = tester.widget(sendFinder);
    expect(send.onPressed, isNull);
    expect(submitted, isNull);
  });
}
