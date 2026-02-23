/// Zuralog — Message Bubble Widget Tests.
///
/// Verifies the visual layout rules of [MessageBubble]:
/// - User bubbles are right-aligned with sage-green background.
/// - AI bubbles are left-aligned with the muted surface background.
/// - When [ChatMessage.clientAction] is non-null, a [DeepLinkCard] is shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/message.dart';
import 'package:zuralog/features/chat/presentation/widgets/deep_link_card.dart';
import 'package:zuralog/features/chat/presentation/widgets/message_bubble.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Wraps a widget in a [MaterialApp] with dark theme for consistent rendering.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: child,
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('MessageBubble', () {
    testWidgets('user bubble is right-aligned', (tester) async {
      final message = ChatMessage(role: 'user', content: 'Hello!');
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      // The outer Row should be end-aligned for user messages.
      final rows = tester.widgetList<Row>(find.byType(Row));
      final outerRow = rows.firstWhere(
        (r) => r.mainAxisAlignment == MainAxisAlignment.end,
        orElse: () => throw TestFailure('No end-aligned Row found'),
      );
      expect(outerRow.mainAxisAlignment, MainAxisAlignment.end);
    });

    testWidgets('user bubble has primary (sage-green) background', (tester) async {
      final message = ChatMessage(role: 'user', content: 'Hello!');
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      // Find a Container with primary color fill.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasPrimary = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == AppColors.primary;
        }
        return false;
      });
      expect(hasPrimary, isTrue);
    });

    testWidgets('AI bubble is left-aligned', (tester) async {
      final message = ChatMessage(role: 'assistant', content: 'Hi there!');
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      final rows = tester.widgetList<Row>(find.byType(Row));
      final outerRow = rows.firstWhere(
        (r) => r.mainAxisAlignment == MainAxisAlignment.start,
        orElse: () => throw TestFailure('No start-aligned Row found'),
      );
      expect(outerRow.mainAxisAlignment, MainAxisAlignment.start);
    });

    testWidgets('AI bubble has aiBubbleDark background in dark theme',
        (tester) async {
      final message = ChatMessage(role: 'assistant', content: 'Hi there!');
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasAiBubble = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == AppColors.aiBubbleDark;
        }
        return false;
      });
      expect(hasAiBubble, isTrue);
    });

    testWidgets('renders DeepLinkCard when clientAction is non-null',
        (tester) async {
      final message = ChatMessage(
        role: 'assistant',
        content: '',
        clientAction: {
          'title': 'Start a run',
          'subtitle': 'Open Strava',
          'url': 'strava://record',
          'fallback_url': 'https://www.strava.com',
        },
      );
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      expect(find.byType(DeepLinkCard), findsOneWidget);
    });

    testWidgets('renders message text when no clientAction', (tester) async {
      final message = ChatMessage(
        role: 'user',
        content: 'Just checking in',
      );
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      expect(find.text('Just checking in'), findsOneWidget);
      expect(find.byType(DeepLinkCard), findsNothing);
    });

    testWidgets('displays timestamp below bubble', (tester) async {
      final message = ChatMessage(
        role: 'user',
        content: 'Timestamp test',
        createdAt: DateTime(2026, 2, 23, 14, 30),
      );
      await tester.pumpWidget(_wrap(MessageBubble(message: message)));
      await tester.pump();

      // Timestamp format: HH:mm
      expect(find.text('14:30'), findsOneWidget);
    });
  });
}
