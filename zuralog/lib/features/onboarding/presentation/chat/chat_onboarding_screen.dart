/// Zuralog — Chat Onboarding Screen.
///
/// Post-sign-up onboarding as a conversation with the AI coach. The user
/// answers each question inline (text, pill, wheel, tile — depending on
/// the step) and their answers appear as their own message bubbles.
///
/// This screen replaces the old [PersonalizationFlowScreen] wizard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/features/onboarding/presentation/chat/controller/onboarding_chat_controller.dart';
import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_text_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_coach_bubble.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_progress_dots.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_typing_indicator.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_user_bubble.dart';

class ChatOnboardingScreen extends ConsumerStatefulWidget {
  const ChatOnboardingScreen({super.key});

  @override
  ConsumerState<ChatOnboardingScreen> createState() =>
      _ChatOnboardingScreenState();
}

class _ChatOnboardingScreenState extends ConsumerState<ChatOnboardingScreen> {
  final ScrollController _scrollController = ScrollController();

  // Layout constants.
  static const double _topBarHeight = 56;
  static const double _chatHorizontalPadding = AppDimens.spaceLg;
  static const double _inputAreaBottomInset = AppDimens.spaceMd;
  static const Duration _autoScrollDuration = Duration(milliseconds: 320);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScrollToBottom() {
    // Run after the frame so the new message's height is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: _autoScrollDuration,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final state = ref.watch(onboardingChatControllerProvider);

    // Auto-scroll whenever the transcript changes length.
    ref.listen<ChatState>(
      onboardingChatControllerProvider,
      (prev, next) {
        if (prev == null || prev.messages.length != next.messages.length) {
          _autoScrollToBottom();
        }
      },
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(currentStep: state.currentStep),
            Expanded(
              child: _Transcript(
                scrollController: _scrollController,
                messages: state.messages,
              ),
            ),
            _InputArea(
              currentStep: state.currentStep,
              isCoachComposing: state.isCoachComposing,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.currentStep});

  final ChatStep currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return SizedBox(
      height: _ChatOnboardingScreenState._topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
        ),
        child: Row(
          children: [
            const CoachBlob(state: BlobState.idle, size: 28),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              'Coach',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
                letterSpacing: -0.15,
              ),
            ),
            const Spacer(),
            OnboardingProgressDots(currentStep: currentStep),
          ],
        ),
      ),
    );
  }
}

// ── Transcript ──────────────────────────────────────────────────────────────

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.scrollController,
    required this.messages,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        left: _ChatOnboardingScreenState._chatHorizontalPadding,
        right: _ChatOnboardingScreenState._chatHorizontalPadding,
        top: AppDimens.spaceLg,
        bottom: AppDimens.spaceLg,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        // Hide the avatar on consecutive coach messages so only the first
        // in a cluster carries the blob. Feels like real chat grouping.
        final showAvatar = index == 0 ||
            messages[index - 1].author != MessageAuthor.coach ||
            msg.author != MessageAuthor.coach;

        switch (msg.kind) {
          case MessageKind.typing:
            return const OnboardingTypingIndicator();
          case MessageKind.text:
            if (msg.author == MessageAuthor.coach) {
              return OnboardingCoachBubble(
                text: msg.text,
                showAvatar: showAvatar,
              );
            }
            return OnboardingUserBubble(text: msg.text);
          case MessageKind.card:
            // Placeholder until card variants land — renders nothing for now.
            return const SizedBox.shrink();
        }
      },
    );
  }
}

// ── Input area ──────────────────────────────────────────────────────────────

class _InputArea extends ConsumerWidget {
  const _InputArea({
    required this.currentStep,
    required this.isCoachComposing,
  });

  final ChatStep currentStep;
  final bool isCoachComposing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final controller = ref.read(onboardingChatControllerProvider.notifier);

    // While the coach is composing, hide the input so the user isn't
    // tempted to type over a reply in-flight.
    final showInput = !isCoachComposing;

    Widget input;
    switch (currentStep) {
      case ChatStep.name:
        input = OnboardingTextInput(
          hint: 'Your name',
          minChars: 2,
          onSubmit: controller.submitName,
        );
      case ChatStep.sex:
      case ChatStep.age:
      case ChatStep.height:
      case ChatStep.weight:
      case ChatStep.focus:
      case ChatStep.goal:
      case ChatStep.tone:
      case ChatStep.connect:
      case ChatStep.finale:
        // Placeholder — each step's custom input will land as we build it.
        input = const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: showInput ? 1.0 : 0.0,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppDimens.spaceLg,
            right: AppDimens.spaceLg,
            bottom: bottomSafe +
                (keyboard > 0 ? AppDimens.spaceSm : _ChatOnboardingScreenState._inputAreaBottomInset),
            top: AppDimens.spaceSm,
          ),
          child: input,
        ),
      ),
    );
  }
}
