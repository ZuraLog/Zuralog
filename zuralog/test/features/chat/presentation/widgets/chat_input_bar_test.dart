/// Zuralog — Chat Input Bar Widget Tests.
///
/// Verifies [ChatInputBar] behavior:
/// - The send button only appears when the text field has content.
/// - The mic button is shown when the field is empty.
/// - The [onSend] callback fires with the correct trimmed text.
/// - The attach button shows a SnackBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/presentation/widgets/chat_input_bar.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Wraps [ChatInputBar] directly as the Scaffold body for reliable hit-testing.
///
/// Placing the widget at the top of the body (not the bottom) ensures it's
/// always within the visible test viewport.
Widget _wrap({required void Function(String) onSend}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: ChatInputBar(onSend: onSend),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('ChatInputBar', () {
    testWidgets('shows mic button when field is empty', (tester) async {
      await tester.pumpWidget(_wrap(onSend: (_) {}));
      await tester.pump();

      // Mic icon button tooltip.
      expect(find.byTooltip('Voice input coming soon'), findsOneWidget);
      // Send button is NOT shown.
      expect(find.byTooltip('Send message'), findsNothing);
    });

    testWidgets('shows send button only when text is entered', (tester) async {
      await tester.pumpWidget(_wrap(onSend: (_) {}));
      await tester.pump();

      // Type some text.
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(find.byTooltip('Voice input coming soon'), findsNothing);
    });

    testWidgets('send button disappears when text is cleared', (tester) async {
      await tester.pumpWidget(_wrap(onSend: (_) {}));
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

      // Use the send icon directly (more reliable than Tooltip-based finder).
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(captured, 'Run 5k today');
    });

    testWidgets('field is cleared after send', (tester) async {
      await tester.pumpWidget(_wrap(onSend: (_) {}));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Clear me');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // After send, field should be empty → send button gone.
      expect(find.byTooltip('Send message'), findsNothing);
    });

    testWidgets('attach button shows SnackBar', (tester) async {
      await tester.pumpWidget(_wrap(onSend: (_) {}));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pump();

      expect(find.text('File attachments coming soon'), findsOneWidget);
    });

    testWidgets('whitespace-only input does not trigger onSend', (tester) async {
      String? captured;
      await tester.pumpWidget(_wrap(onSend: (text) => captured = text));
      await tester.pump();

      // Spaces should not make the send button appear.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send message'), findsNothing);
      expect(captured, isNull);
    });
  });
}
