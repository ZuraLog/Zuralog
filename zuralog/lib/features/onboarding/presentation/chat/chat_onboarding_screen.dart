/// Zuralog — Chat Onboarding Screen.
///
/// Post-sign-up onboarding as a conversation with the AI coach. The user
/// answers each question inline (text, pill, wheel, tile — depending on
/// the step) and their answers appear as their own message bubbles. The
/// coach reacts dynamically, drops info cards (BMR, finale profile), and
/// ends with a "Meet your coach" CTA that persists the profile and lands
/// the user on Today.
///
/// This screen replaces the old form-style [PersonalizationFlowScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';
import 'package:zuralog/features/onboarding/presentation/chat/cards/onboarding_autonomous_action_card.dart';
import 'package:zuralog/features/onboarding/presentation/chat/cards/onboarding_bmr_card.dart';
import 'package:zuralog/features/onboarding/presentation/chat/cards/onboarding_focus_preview_card.dart';
import 'package:zuralog/features/onboarding/presentation/chat/cards/onboarding_profile_card.dart';
import 'package:zuralog/features/onboarding/presentation/chat/cards/onboarding_tone_sample_card.dart';
import 'package:zuralog/features/onboarding/presentation/chat/controller/onboarding_chat_controller.dart';
import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_chip_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_focus_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_integrations_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_pill_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_text_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_date_picker_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/inputs/onboarding_unit_wheel_input.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_coach_bubble.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_progress_dots.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_typing_indicator.dart';
import 'package:zuralog/features/onboarding/presentation/chat/widgets/onboarding_user_bubble.dart';
import 'package:zuralog/shared/widgets/widgets.dart' show
    ZChipSingleSelect,
    ZChipMultiSelect,
    ZChipOption,
    ZChatTextField;

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
    final state = ref.watch(onboardingChatControllerProvider);

    // ref.listen MUST be called directly in the build method of a
    // ConsumerStatefulWidget — never inside a nested Builder.
    ref.listen<ChatState>(
      onboardingChatControllerProvider,
      (prev, next) {
        if (prev == null || prev.messages.length != next.messages.length) {
          _autoScrollToBottom();
        }
      },
    );

    // Force dark mode for the onboarding surface regardless of the system
    // theme — per docs/design.md "Dark mode is the primary experience."
    // Descendants using AppColorsOf(context) resolve to dark tokens inside.
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Builder(
        builder: (ctx) {
          final colors = AppColorsOf(ctx);
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
                      profile: state.profile,
                    ),
                  ),
                  _InputArea(
                    state: state,
                    onFinale: () => _handleFinale(state.profile),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleFinale(OnboardingProfile profile) async {
    try {
      await ref.read(userProfileProvider.notifier).update(
            onboardingComplete: true,
            nickname:
                (profile.name ?? '').isNotEmpty ? profile.name : null,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthday: profile.birthday,
            gender: profile.sex,
            focusArea: profile.focus,
            primaryGoal:
                (profile.goal ?? '').trim().isNotEmpty ? profile.goal : null,
            tone: profile.tone,
            dietaryRestrictions: profile.dietaryRestrictions,
            injuries: profile.injuries,
            fitnessLevel: profile.trainingExperience,
            sleepPattern: profile.sleepPattern,
            healthFrustration:
                (profile.healthFrustration ?? '').trim().isNotEmpty
                    ? profile.healthFrustration
                    : null,
            // Mark catch-up as completed for fresh users so they never see
            // the catch-up intro sheet.
            profileCatchupStatus: 'completed',
          );
    } catch (_) {
      // Non-fatal — router navigates by auth state regardless.
    }
    if (!mounted) return;
    // Clear the replay flag so the router guard resumes normal behaviour.
    ref.read(isReplayingOnboardingProvider.notifier).state = false;
    ctxGo(context);
  }

  void ctxGo(BuildContext context) {
    context.go(RouteNames.todayPath);
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
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
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
    required this.profile,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final OnboardingProfile profile;

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
            return _CardMessage(
              cardKind: msg.cardKind ?? ChatCardKind.bmr,
              profile: profile,
            );
        }
      },
    );
  }
}

/// Renders whichever card variant the coach "sent" — BMR, focus preview,
/// activity baseline, or the finale profile.
class _CardMessage extends StatelessWidget {
  const _CardMessage({
    required this.cardKind,
    required this.profile,
  });

  final ChatCardKind cardKind;
  final OnboardingProfile profile;

  @override
  Widget build(BuildContext context) {
    switch (cardKind) {
      case ChatCardKind.bmr:
        return OnboardingBmrCard(
          bmrCalories: _estimateBmr(profile),
        );
      case ChatCardKind.toneSample:
        return OnboardingToneSampleCard(toneId: profile.tone ?? 'warm');
      case ChatCardKind.autonomousAction:
        return OnboardingAutonomousActionCard(
          focusLabel: _focusDisplayLabel(profile.focus),
        );
      case ChatCardKind.focusPreview:
        return OnboardingFocusPreviewCard(
          focusId: profile.focus ?? 'overall',
        );
      case ChatCardKind.finaleProfile:
        return OnboardingProfileCard(profile: profile);
      case ChatCardKind.activityBaseline:
        // Reserved for a future card variant.
        return const SizedBox.shrink();
    }
  }

  /// Friendly display label for the user's picked focus. Used by the
  /// autonomous-action card to personalize task #2.
  static String _focusDisplayLabel(String? focusId) {
    switch (focusId) {
      case 'sleep':
        return 'Sleep';
      case 'activity':
        return 'Activity';
      case 'nutrition':
        return 'Nutrition';
      case 'overall':
        return 'Overall wellness';
      default:
        return 'your focus';
    }
  }

  /// Mifflin-St Jeor — widely used clinical BMR estimator. Falls back to a
  /// reasonable default if we don't have the full picture yet.
  static int _estimateBmr(OnboardingProfile p) {
    if (p.heightCm == null || p.weightKg == null || p.birthday == null) {
      return 1700;
    }
    final kg = p.weightKg!;
    final cm = p.heightCm!;
    final now = DateTime.now();
    int ageInt = now.year - p.birthday!.year;
    if (now.month < p.birthday!.month ||
        (now.month == p.birthday!.month &&
            now.day < p.birthday!.day)) {
      ageInt--;
    }
    final age = ageInt.toDouble();
    // Male: 10w + 6.25h − 5a + 5 | Female: − 161.  For "other" we average.
    final offset = p.sex == 'male'
        ? 5
        : p.sex == 'female'
            ? -161
            : -78;
    final bmr = (10 * kg) + (6.25 * cm) - (5 * age) + offset;
    return bmr.round();
  }
}

// ── Input area ──────────────────────────────────────────────────────────────

class _InputArea extends ConsumerWidget {
  const _InputArea({
    required this.state,
    required this.onFinale,
  });

  final ChatState state;
  final VoidCallback onFinale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final controller = ref.read(onboardingChatControllerProvider.notifier);
    final showInput = !state.isCoachComposing;

    Widget input;
    switch (state.currentStep) {
      case ChatStep.name:
        input = OnboardingTextInput(
          hint: 'Your name',
          minChars: 2,
          onSubmit: controller.submitName,
        );
      case ChatStep.sex:
        input = OnboardingPillInput(
          layout: PillLayout.row,
          options: const [
            OnboardingPillOption(id: 'female', label: 'Female'),
            OnboardingPillOption(id: 'male', label: 'Male'),
            OnboardingPillOption(id: 'other', label: 'Other'),
          ],
          onSelect: controller.submitSex,
        );
      case ChatStep.birthday:
        input = OnboardingDatePickerInput(
          initialDate: state.profile.birthday,
          onSubmit: controller.submitBirthday,
        );
      case ChatStep.height:
        input = OnboardingHeightInput(
          onSubmit: controller.submitHeight,
        );
      case ChatStep.weight:
        input = OnboardingWeightInput(
          onSubmit: controller.submitWeight,
        );
      case ChatStep.focus:
        input = OnboardingFocusInput(
          options: [
            OnboardingFocusOption(
              id: 'sleep',
              icon: Icons.nightlight_round,
              accent: AppColors.categorySleep,
              title: 'Sleep',
              subtitle: 'Deeper nights',
            ),
            OnboardingFocusOption(
              id: 'activity',
              icon: Icons.directions_run_rounded,
              accent: AppColors.categoryActivity,
              title: 'Activity',
              subtitle: 'Move more',
            ),
            OnboardingFocusOption(
              id: 'nutrition',
              icon: Icons.eco_rounded,
              accent: AppColors.categoryNutrition,
              title: 'Nutrition',
              subtitle: 'Eat smarter',
            ),
            OnboardingFocusOption(
              id: 'overall',
              icon: Icons.spa_rounded,
              accent: AppColors.primary,
              title: 'Overall',
              subtitle: 'Feel better',
            ),
          ],
          onSelect: controller.submitFocus,
        );
      case ChatStep.goal:
        input = OnboardingChipInput(
          options: _goalOptionsForFocus(state.profile.focus),
          onSubmit: controller.submitGoal,
        );
      case ChatStep.tone:
        input = OnboardingPillInput(
          layout: PillLayout.wrap,
          options: const [
            OnboardingPillOption(id: 'warm', label: 'Warm'),
            OnboardingPillOption(id: 'direct', label: 'Direct'),
            OnboardingPillOption(id: 'minimal', label: 'Minimal'),
            OnboardingPillOption(id: 'thorough', label: 'Thorough'),
          ],
          onSelect: controller.submitTone,
        );
      case ChatStep.diet:
        input = ZChipMultiSelect<String>(
          options: const [
            ZChipOption(value: 'vegetarian', label: 'Vegetarian'),
            ZChipOption(value: 'vegan', label: 'Vegan'),
            ZChipOption(value: 'gluten_free', label: 'Gluten-free'),
            ZChipOption(value: 'keto', label: 'Keto'),
            ZChipOption(value: 'halal', label: 'Halal'),
            ZChipOption(value: 'kosher', label: 'Kosher'),
            ZChipOption(value: 'other', label: 'Other'),
          ],
          values: state.profile.dietaryRestrictions,
          exclusiveLabel: 'None',
          onChanged: controller.submitDiet,
        );
      case ChatStep.limitations:
        input = ZChipMultiSelect<String>(
          options: const [
            ZChipOption(value: 'lower_back', label: 'Lower back'),
            ZChipOption(value: 'knees', label: 'Knees'),
            ZChipOption(value: 'shoulders', label: 'Shoulders'),
            ZChipOption(value: 'wrists', label: 'Wrists'),
            ZChipOption(value: 'other', label: 'Other'),
          ],
          values: state.profile.injuries,
          exclusiveLabel: "I'm good",
          onChanged: controller.submitLimitations,
        );
      case ChatStep.training:
        input = ZChipSingleSelect<String>(
          options: const [
            ZChipOption(value: 'beginner', label: 'New to this'),
            ZChipOption(value: 'active', label: 'Consistently active'),
            ZChipOption(value: 'athletic', label: 'Highly trained'),
          ],
          value: state.profile.trainingExperience,
          onChanged: controller.submitTraining,
        );
      case ChatStep.sleep:
        input = ZChipSingleSelect<String>(
          options: const [
            ZChipOption(value: 'great', label: 'I sleep great'),
            ZChipOption(value: 'hard_to_fall_asleep', label: 'Hard to fall asleep'),
            ZChipOption(value: 'wake_up_a_lot', label: 'Wake up a lot'),
            ZChipOption(value: 'short_hours', label: 'Short hours'),
          ],
          value: state.profile.sleepPattern,
          onChanged: controller.submitSleep,
        );
      case ChatStep.frustration:
        input = ZChatTextField(
          maxLength: 120,
          placeholder: "One sentence — or tap send to skip.",
          allowEmptySubmit: true,
          onSubmit: (text) => controller.submitFrustration(text),
        );
      case ChatStep.connect:
        input = OnboardingIntegrationsInput(
          onSubmit: controller.submitIntegrations,
        );
      case ChatStep.source:
        input = OnboardingPillInput(
          layout: PillLayout.wrap,
          options: const [
            OnboardingPillOption(id: 'friend', label: 'Friend'),
            OnboardingPillOption(id: 'instagram', label: 'Instagram'),
            OnboardingPillOption(id: 'tiktok', label: 'TikTok'),
            OnboardingPillOption(id: 'podcast', label: 'Podcast'),
            OnboardingPillOption(id: 'app_store', label: 'App Store'),
            OnboardingPillOption(id: 'doctor', label: 'Doctor'),
            OnboardingPillOption(id: 'other', label: 'Somewhere else'),
          ],
          onSelect: controller.submitDiscoverySource,
        );
      case ChatStep.finale:
        input = _MeetYourCoachButton(onPressed: onFinale);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
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
                (keyboard > 0
                    ? AppDimens.spaceSm
                    : _ChatOnboardingScreenState._inputAreaBottomInset),
            top: AppDimens.spaceSm,
          ),
          child: input,
        ),
      ),
    );
  }

  // Goals adapt to the user's focus pick so the suggestions feel tailored.
  List<String> _goalOptionsForFocus(String? focus) {
    switch (focus) {
      case 'sleep':
        return const [
          'Sleep 8 hours',
          'Fall asleep faster',
          'Fewer wake-ups',
          'Morning energy',
          'Consistent schedule',
        ];
      case 'activity':
        return const [
          'Train 4x a week',
          'Build strength',
          'Run a 5K',
          'Walk 10k steps',
          'Stay consistent',
        ];
      case 'nutrition':
        return const [
          'Eat more protein',
          'Cut processed food',
          'Lose weight',
          'Gain muscle',
          'Drink more water',
        ];
      case 'overall':
      default:
        return const [
          'More energy',
          'Less stress',
          'Better mood',
          'Build habits',
          'Feel balanced',
        ];
    }
  }
}

/// Final CTA that shows only at the finale step.
class _MeetYourCoachButton extends StatelessWidget {
  const _MeetYourCoachButton({required this.onPressed});

  final VoidCallback onPressed;

  static const double _buttonHeight = 52;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _buttonHeight,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(_buttonHeight / 2),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_buttonHeight / 2),
                child: const IgnorePointer(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.sage,
                    opacity: 0.55,
                    animate: true,
                  ),
                ),
              ),
            ),
            Text(
              'Meet your coach',
              style: AppTextStyles.labelLarge.copyWith(
                color: const Color(0xFF1A2E22),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
