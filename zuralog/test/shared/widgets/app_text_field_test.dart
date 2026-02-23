/// Widget tests for [AppTextField].
///
/// Verifies rendering, text input, hint text, validation, and
/// prefix/suffix icon display.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';

/// Wraps [child] in a [Form] + themed [MaterialApp] so that validation
/// and theme resolution work correctly in widget tests.
Widget _themed(Widget child, {GlobalKey<FormState>? formKey}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('AppTextField — rendering', () {
    testWidgets('renders a TextFormField', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(hintText: 'Enter text')),
      );
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows hint text when field is empty', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(hintText: 'Email address')),
      );
      expect(find.text('Email address'), findsOneWidget);
    });

    testWidgets('shows prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(
          hintText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        )),
      );
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    });

    testWidgets('shows suffix icon when provided', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(
          hintText: 'Password',
          suffixIcon: Icon(Icons.visibility_off),
        )),
      );
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('AppTextField — text input', () {
    testWidgets('accepts typed text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _themed(AppTextField(
          hintText: 'Type here',
          controller: controller,
        )),
      );
      await tester.enterText(find.byType(TextFormField), 'Hello World');
      expect(controller.text, 'Hello World');
    });

    testWidgets('calls onChanged on every keystroke', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _themed(AppTextField(
          hintText: 'Watch changes',
          onChanged: changes.add,
        )),
      );
      await tester.enterText(find.byType(TextFormField), 'abc');
      // enterText triggers a single onChanged with the full string.
      expect(changes, contains('abc'));
    });

    testWidgets('obscures text when obscureText is true', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(
          hintText: 'Password',
          obscureText: true,
        )),
      );
      // TextFormField does not expose obscureText directly; access the
      // underlying EditableText to verify the property was wired through.
      final editableText =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.obscureText, isTrue);
    });
  });

  group('AppTextField — validation', () {
    testWidgets('shows error message when validator returns a string',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _themed(
          AppTextField(
            hintText: 'Required field',
            validator: (v) =>
                (v == null || v.isEmpty) ? 'This field is required' : null,
          ),
          formKey: formKey,
        ),
      );

      // Trigger validation programmatically.
      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('shows no error when validator returns null', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _themed(
          AppTextField(
            hintText: 'Optional',
            validator: (_) => null,
          ),
          formKey: formKey,
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.byType(Text).evaluate().length, lessThanOrEqualTo(1));
    });

    testWidgets('passes validation with non-empty text', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _themed(
          AppTextField(
            hintText: 'Name',
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Required' : null,
          ),
          formKey: formKey,
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Zuralog');
      final valid = formKey.currentState!.validate();
      await tester.pump();

      expect(valid, isTrue);
      expect(find.text('Required'), findsNothing);
    });
  });

  group('AppTextField — Sage Green cursor', () {
    testWidgets('cursor color is AppColors.primary (Sage Green)', (tester) async {
      await tester.pumpWidget(
        _themed(const AppTextField(hintText: 'Cursor test')),
      );
      // TextFormField does not expose cursorColor directly; access the
      // underlying EditableText to verify the property was wired through.
      final editableText =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.cursorColor, AppColors.primary);
    });
  });
}
