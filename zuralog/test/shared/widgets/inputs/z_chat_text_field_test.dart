import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

void main() {
  testWidgets('ZChatTextField enforces maxLength via inputFormatter', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 10,
          placeholder: 'one sentence',
          onSubmit: (_) {},
        ),
      ),
    ));

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    final TextField tf = tester.widget(textField);
    final formatter = tf.inputFormatters!.first as LengthLimitingTextInputFormatter;
    expect(formatter.maxLength, 10);
  });

  testWidgets('ZChatTextField fires onSubmit with trimmed value on send', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 40,
          placeholder: 'one sentence',
          onSubmit: (text) => submitted = text,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '  hello world  ');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(submitted, 'hello world');
  });

  testWidgets('ZChatTextField ignores send when empty by default', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 40,
          onSubmit: (text) => submitted = text,
        ),
      ),
    ));

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(submitted, isNull);
  });

  testWidgets('ZChatTextField submits empty string when allowEmptySubmit is true', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZChatTextField(
          maxLength: 40,
          allowEmptySubmit: true,
          onSubmit: (text) => submitted = text,
        ),
      ),
    ));

    // Tap the send button directly — it's enabled even when the field is empty.
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(submitted, '');
  });
}
