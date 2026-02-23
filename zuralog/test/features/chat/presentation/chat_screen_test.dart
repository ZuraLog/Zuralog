/// Zuralog — Coach Chat Screen Tests.
///
/// Tests the [ChatScreen] widget with all Riverpod providers overridden
/// so no real network operations occur. Verifies smoke rendering, input
/// bar presence, loading/connecting state, and the sendMessage dispatch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/network/ws_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/data/chat_repository.dart';
import 'package:zuralog/features/chat/domain/chat_providers.dart';
import 'package:zuralog/features/chat/domain/message.dart';
import 'package:zuralog/features/chat/presentation/chat_screen.dart';
import 'package:zuralog/features/chat/presentation/widgets/chat_input_bar.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────────

/// A [SecureStorage] stub that always returns a fixed token.
class _FakeSecureStorage extends SecureStorage {
  @override
  Future<String?> getAuthToken() async => 'test-token';
}

/// A [WsClient] that never opens a real socket.
class _FakeWsClient extends WsClient {
  _FakeWsClient() : super(baseUrl: 'ws://localhost:0');

  @override
  void connect(String token) {
    // No-op: avoids real WebSocket.
  }

  @override
  void send(String message) {
    // No-op.
  }
}

/// A [ChatNotifier] stub that records [sendMessage] calls.
///
/// Initialises the [StateNotifier] with [initialState] directly by passing
/// it to the super constructor (bypassing the real repository connect logic).
class _StubChatNotifier extends ChatNotifier {
  _StubChatNotifier({
    required ChatRepository repository,
    required Ref ref,
    required ChatState initialState,
    required List<String>? sent,
  })  : _sent = sent,
        super(repository, ref) {
    // Replace the default empty state with the provided initial state.
    state = initialState;
  }

  final List<String>? _sent;

  @override
  void connect(String token) {
    // No-op in tests.
  }

  @override
  void sendMessage(String text) {
    _sent?.add(text);
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: 'user', content: text),
      ],
    );
  }

  @override
  Future<void> loadHistory() async {
    // No-op in tests.
  }
}

// ── Harness ────────────────────────────────────────────────────────────────────

/// Builds a [ProviderScope] with all providers stubbed.
///
/// [chatState] is the initial [ChatState] for the notifier.
/// [connectionStatus] controls the connection status stream.
/// [sentMessages] is populated by [sendMessage] calls.
Widget _buildHarness({
  ChatState? chatState,
  ConnectionStatus connectionStatus = ConnectionStatus.connected,
  List<String>? sentMessages,
}) {
  final stateToUse = chatState ?? const ChatState();
  final fakeWsClient = _FakeWsClient();
  final fakeApiClient = ApiClient();
  final fakeRepo = ChatRepository(
    wsClient: fakeWsClient,
    apiClient: fakeApiClient,
  );

  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      wsClientProvider.overrideWithValue(fakeWsClient),
      chatRepositoryProvider.overrideWithValue(fakeRepo),
      chatNotifierProvider.overrideWith(
        (ref) => _StubChatNotifier(
          repository: fakeRepo,
          ref: ref,
          initialState: stateToUse,
          sent: sentMessages,
        ),
      ),
      connectionStatusProvider.overrideWith(
        (_) => Stream.value(connectionStatus),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const ChatScreen(),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('ChatScreen', () {
    testWidgets('smoke test: renders without crashing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows input bar', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.byType(ChatInputBar), findsOneWidget);
    });

    testWidgets('shows connecting banner when status is connecting',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(connectionStatus: ConnectionStatus.connecting),
      );
      await tester.pump();
      expect(find.textContaining('Connecting'), findsOneWidget);
    });

    testWidgets('shows disconnected banner when status is disconnected',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(connectionStatus: ConnectionStatus.disconnected),
      );
      await tester.pump();
      expect(find.textContaining('Disconnected'), findsOneWidget);
    });

    testWidgets('no banner shown when connected', (tester) async {
      await tester.pumpWidget(
        _buildHarness(connectionStatus: ConnectionStatus.connected),
      );
      await tester.pump();
      expect(find.textContaining('Connecting'), findsNothing);
      expect(find.textContaining('Disconnected'), findsNothing);
    });

    testWidgets('dispatches sendMessage when user submits text', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_buildHarness(sentMessages: sent));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hello coach!');
      await tester.pumpAndSettle();

      // Use the send icon directly for reliable hit-testing.
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sent, contains('Hello coach!'));
    });

    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Your AI Coach'), findsOneWidget);
    });

    testWidgets('renders user message bubble when state has messages',
        (tester) async {
      final state = ChatState(
        messages: [
          ChatMessage(role: 'user', content: 'Hi there'),
          ChatMessage(role: 'assistant', content: 'Hello! How can I help?'),
        ],
      );
      await tester.pumpWidget(_buildHarness(chatState: state));
      await tester.pump();
      expect(find.text('Hi there'), findsOneWidget);
    });
  });
}
