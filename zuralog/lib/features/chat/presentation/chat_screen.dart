/// Zuralog Edge Agent — Coach Chat Screen.
///
/// The primary AI coaching conversation interface. Uses a WebSocket
/// connection established in [initState] to stream messages in real-time.
/// The message list is displayed in reverse order (newest at bottom)
/// with smooth scroll-to-bottom on new messages.
///
/// Key features:
/// - [RefreshIndicator] for pull-to-refresh WebSocket reconnection.
/// - [TypingIndicator] shown while the AI is composing a response.
/// - Connection status banner at the top when disconnected or reconnecting.
/// - Frosted-glass [ChatInputBar] floating at the bottom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/ws_client.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/chat_providers.dart';
import 'package:zuralog/features/chat/domain/message.dart';
import 'package:zuralog/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:zuralog/features/chat/presentation/widgets/message_bubble.dart';
import 'package:zuralog/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:zuralog/core/speech/speech.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── Chat Screen ───────────────────────────────────────────────────────────────

/// The Coach Chat screen — full-screen AI conversation interface.
///
/// Connects to the Cloud Brain via WebSocket on init, accumulates streaming
/// messages into a [ListView], and provides [ChatInputBar] for user input.
/// Supports pull-to-refresh reconnection via [RefreshIndicator].
class ChatScreen extends ConsumerStatefulWidget {
  /// Creates a [ChatScreen].
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// Scroll controller used to animate to the bottom on new messages.
  final ScrollController _scrollController = ScrollController();

  /// Tracks the number of messages at the previous build to detect new ones.
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Kick off the WebSocket connection after the first frame, so that
    // the ProviderScope is fully initialised and we can safely call ref.read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectWithToken();
    });
  }

  /// Reads the stored auth token and initiates the WebSocket connection.
  ///
  /// Falls back to an empty token string if no token is stored — the
  /// backend will reject the connection and we surface the disconnected
  /// banner to the user.
  Future<void> _connectWithToken() async {
    final secureStorage = ref.read(secureStorageProvider);
    final token = await secureStorage.getAuthToken() ?? '';
    if (!mounted) return;
    ref.read(chatNotifierProvider.notifier).connect(token);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the message list to the bottom with a gentle animation.
  ///
  /// Called after a new message is added so the user always sees
  /// the latest message without manually scrolling.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scroll to bottom when new messages arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatState.messages.length > _previousMessageCount) {
        _previousMessageCount = chatState.messages.length;
        _scrollToBottom();
      }
    });

    // Listen for speech state transitions to handle errors and analytics.
    ref.listen<SpeechState>(speechNotifierProvider, (previous, next) {
      // ── Error handling ──────────────────────────────────────────────
      if (next.status == SpeechStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_speechErrorMessage(next.errorMessage!)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // ── Analytics: voice_input_completed ───────────────────────────
      // Captured here (not in onVoiceStop) so we always read the final
      // recognized text after the plugin delivers its last result —
      // the stop callback fires before the final async result arrives.
      if (previous?.isListening == true && next.isFinal) {
        ref.read(analyticsServiceProvider).capture(
          event: 'voice_input_completed',
          properties: {
            'text_length': next.recognizedText.length,
            'has_text': next.recognizedText.isNotEmpty,
          },
        );
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Coach',
          style: AppTextStyles.h2.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          // Connection status dot.
          _ConnectionDot(connectionAsync: connectionAsync),
          // Profile avatar — opens the side panel.
          const Padding(
            padding: EdgeInsets.only(right: AppDimens.spaceMd),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Connection status banner ──────────────────────────────────
          _ConnectionBanner(connectionAsync: connectionAsync),

          // ── Listening indicator ───────────────────────────────────────
          Builder(builder: (context) {
            final speechState = ref.watch(speechNotifierProvider);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: speechState.isListening ? null : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: speechState.isListening
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceSm,
                      ),
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Row(
                        children: [
                          _PulsingDot(),
                          const SizedBox(width: AppDimens.spaceSm),
                          Expanded(
                            child: Text(
                              speechState.recognizedText.isEmpty
                                  ? 'Listening…'
                                  : speechState.recognizedText,
                              style: AppTextStyles.body.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          }),

          // ── Message list with pull-to-reconnect ──────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(chatNotifierProvider.notifier).reconnect(),
              child: _MessageList(
                messages: chatState.messages,
                isTyping: chatState.isTyping,
                scrollController: _scrollController,
              ),
            ),
          ),

          // ── Input bar (pinned at bottom) ──────────────────────────────
          Builder(builder: (context) {
            final speechState = ref.watch(speechNotifierProvider);
            return ChatInputBar(
              onSend: (text) {
                ref.read(chatNotifierProvider.notifier).sendMessage(text);
              },
              onSendWithAttachments: (text, attachments) {
                final attachmentRepo = ref.read(attachmentRepositoryProvider);
                ref
                    .read(chatNotifierProvider.notifier)
                    .sendMessageWithAttachments(text, attachments, attachmentRepo);
              },
              onVoiceStart: () async {
                final notifier = ref.read(speechNotifierProvider.notifier);

                // If a previous session ended in error (e.g. permission
                // permanently denied), don't silently loop — the ref.listen
                // above will surface a SnackBar. Return early.
                if (speechState.status == SpeechStatus.error) return;

                // Lazy-initialize on first use.
                if (!speechState.isAvailable) {
                  final available = await notifier.initialize();
                  if (!available && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Speech recognition is not available on this device',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                }
                await notifier.startListening();
                ref.read(analyticsServiceProvider).capture(
                  event: 'voice_input_started',
                );
              },
              onVoiceStop: () {
                // Analytics are captured in the ref.listen above, after the
                // plugin delivers its final result asynchronously.
                ref.read(speechNotifierProvider.notifier).stopListening();
              },
              onVoiceCancel: () {
                ref.read(speechNotifierProvider.notifier).cancelListening();
              },
              isListening: speechState.isListening,
              recognizedText: speechState.recognizedText,
              soundLevel: speechState.soundLevel,
            );
          }),
        ],
      ),
    );
  }
}

// ── Message List ──────────────────────────────────────────────────────────────

/// The scrollable message list.
///
/// Renders messages in chronological order using a [ListView.builder].
/// When [isTyping] is true, a [TypingIndicator] is appended after the
/// last message.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.isTyping,
    required this.scrollController,
  });

  /// The messages to display.
  final List<ChatMessage> messages;

  /// Whether the AI is currently typing.
  final bool isTyping;

  /// Scroll controller for programmatic scrolling.
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isTyping) {
      return const _EmptyState();
    }

    final itemCount = messages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(
        top: AppDimens.spaceMd,
        bottom: AppDimens.spaceLg,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Last item = typing indicator when AI is composing.
        if (isTyping && index == messages.length) {
          return const TypingIndicator();
        }
        return MessageBubble(message: messages[index]);
      },
    );
  }
}

// ── Connection Status Banner ──────────────────────────────────────────────────

/// A slim status banner shown at the top of the screen when the WebSocket
/// is not connected.
///
/// Hidden when the connection is in the [ConnectionStatus.connected] state.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connectionAsync});

  /// The async connection status value from [connectionStatusProvider].
  final AsyncValue<ConnectionStatus> connectionAsync;

  @override
  Widget build(BuildContext context) {
    final status = connectionAsync.valueOrNull;

    // Don't show the banner when connected.
    if (status == ConnectionStatus.connected || status == null) {
      return const SizedBox.shrink();
    }

    final isConnecting = status == ConnectionStatus.connecting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      color: isConnecting
          ? AppColors.secondaryDark.withValues(alpha: 0.85)
          : AppColors.accentDark.withValues(alpha: 0.85),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isConnecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            isConnecting ? 'Connecting…' : 'Disconnected — pull to reconnect',
            style: AppTextStyles.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Connection Dot ────────────────────────────────────────────────────────────

/// A small status dot in the app bar indicating connection state.
///
/// Green = connected, amber = connecting, red = disconnected.
class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.connectionAsync});

  /// The async connection status value.
  final AsyncValue<ConnectionStatus> connectionAsync;

  @override
  Widget build(BuildContext context) {
    final status = connectionAsync.valueOrNull;

    final Color dotColor;
    final String tooltip;

    switch (status) {
      case ConnectionStatus.connected:
        dotColor = AppColors.statusConnected;
        tooltip = 'Connected';
      case ConnectionStatus.connecting:
        dotColor = AppColors.statusConnecting;
        tooltip = 'Connecting…';
      case ConnectionStatus.disconnected:
      case null:
        dotColor = AppColors.accentDark;
        tooltip = 'Disconnected';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: dotColor.withValues(alpha: 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

/// Placeholder shown when there are no messages yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Text(
              'Your AI Coach',
              style: AppTextStyles.h2.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Ask me anything about your health,\nfitness goals, or workout plans.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Speech Error Helper ───────────────────────────────────────────────────────

/// Maps speech recognition error codes to user-friendly messages.
String _speechErrorMessage(String error) {
  if (error.contains('permission') || error.contains('denied')) {
    return 'Microphone permission is required for voice input. '
        'Please enable it in Settings.';
  }
  if (error.contains('network')) {
    return 'Speech recognition requires a network connection on some devices.';
  }
  if (error.contains('busy') || error.contains('recognizer')) {
    return 'Speech recognition is busy. Please try again.';
  }
  return 'Voice input error. Please try again.';
}

// ── Pulsing Dot ───────────────────────────────────────────────────────────────

/// A small pulsing green dot indicating active listening.
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: _animation.value),
        ),
      ),
    );
  }
}
