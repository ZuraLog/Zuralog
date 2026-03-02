/// Zuralog — Chat Input Bar Widget Tests.
///
/// Verifies [ChatInputBar] behavior:
/// - The send button only appears when the text field has content.
/// - The mic button (hold-to-talk) is shown when the field is empty.
/// - The [onSend] callback fires with the correct trimmed text.
/// - The attach button shows a SnackBar.
/// - Voice callbacks fire on long-press gestures.
/// - Recognized text fills the input field when listening stops.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/presentation/widgets/chat_input_bar.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _wrap({
  void Function(String)? onSend,
  VoidCallback? onVoiceStart,
  VoidCallback? onVoiceStop,
  VoidCallback? onVoiceCancel,
  bool isListening = false,
  String recognizedText = '',
  double soundLevel = 0.0,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: ChatInputBar(
        onSend: onSend ?? (_) {},
        onVoiceStart: onVoiceStart,
        onVoiceStop: onVoiceStop,
        onVoiceCancel: onVoiceCancel,
        isListening: isListening,
        recognizedText: recognizedText,
        soundLevel: soundLevel,
      ),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('ChatInputBar', () {
    testWidgets('shows mic icon when field is empty', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('shows send button only when text is entered', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('send button disappears when text is cleared', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsNothing);
    });

    testWidgets('onSend callback fires with correct text', (tester) async {
      String? captured;
      await tester.pumpWidget(_wrap(onSend: (text) => captured = text));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Run 5k today');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(captured, 'Run 5k today');
    });

    testWidgets('field is cleared after send', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Clear me');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send message'), findsNothing);
    });

    testWidgets('attach button shows SnackBar', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pump();

      expect(find.text('File attachments coming soon'), findsOneWidget);
    });

    testWidgets('whitespace-only input does not trigger onSend', (tester) async {
      String? captured;
      await tester.pumpWidget(_wrap(onSend: (text) => captured = text));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send message'), findsNothing);
      expect(captured, isNull);
    });

    // ── Voice Input ────────────────────────────────────────────────────

    testWidgets('shows filled mic icon when isListening is true', (tester) async {
      await tester.pumpWidget(_wrap(isListening: true));
      await tester.pump();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('long press on mic triggers onVoiceStart', (tester) async {
      var started = false;
      await tester.pumpWidget(_wrap(onVoiceStart: () => started = true));
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('recognized text fills input when listening stops', (tester) async {
      await tester.pumpWidget(_wrap(
        isListening: true,
        recognizedText: 'hello world',
      ));
      await tester.pump();

      await tester.pumpWidget(_wrap(
        isListening: false,
        recognizedText: 'hello world',
      ));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'hello world');
    });

    testWidgets('empty recognized text does not fill input when listening stops',
        (tester) async {
      await tester.pumpWidget(_wrap(
        isListening: true,
        recognizedText: '',
      ));
      await tester.pump();

      await tester.pumpWidget(_wrap(
        isListening: false,
        recognizedText: '',
      ));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '');
    });
  });
}
