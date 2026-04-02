/// Zuralog — 8-Step Onboarding Flow Screen (v3.2).
///
/// Expanded from 6 to 8 steps: WelcomeStep, NameStep, GoalsStep, PersonaStep,
/// FitnessLevelStep, ConnectAppsStep, NotificationsStep, DiscoveryStep.
///
/// New fields collected:
///   - `nickname` (Step 2) — sent to PATCH /api/v1/preferences
///   - `fitness_level` (Step 5) — sent to PATCH /api/v1/preferences
///     NOTE: fitness_level is a new backend field. The backend ignores unknown
///     fields in the PATCH body, so this is forward-compatible with the
///     current backend until the field is added.
///
/// **All existing backend wiring is preserved:**
///   - PATCH /api/v1/preferences with goals, persona, proactivity, notifications
///   - UserProfileNotifier.update with onboardingComplete: true + nickname
///   - PostHog analytics events (all preserved, step counts updated)
///   - Sentry error capture on failure
///
/// Skip architecture: top-right "Skip" link visible on steps 2–8.
/// Skipping a step sends the default/empty value for that step's fields.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/analytics/feature_flag_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/presentation/steps/connect_apps_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/discovery_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/fitness_level_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/goals_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/name_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/notifications_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/persona_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Persona ID mapping ────────────────────────────────────────────────────────

/// Maps the UI persona IDs used in [PersonaStep] to the API enum values
/// accepted by `/api/v1/preferences` (`CoachPersona` enum on the backend).
const Map<String, String> _personaApiKey = {
  'motivator': 'tough_love',
  'analyst': 'balanced',
  'coach': 'gentle',
};

// ── Proactivity mapping ───────────────────────────────────────────────────────

/// Maps the slider float value (0.0–1.0) to the API enum string for
/// `/api/v1/preferences` (`ProactivityLevel` enum on the backend).
String _proactivityApiKey(double value) {
  if (value < 0.35) return 'low';
  if (value < 0.70) return 'medium';
  return 'high';
}

// ── Total page count ──────────────────────────────────────────────────────────

/// Total number of onboarding steps. Updated from 6 → 8 in v3.2.
const int _totalPages = 8;

// ── Screen ─────────────────────────────────────────────────────────────────────

/// 8-step onboarding flow shown once after a new user registers.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingFlowScreen].
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  // ── Page controller ────────────────────────────────────────────────────────

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Feature flag: onboarding step order ───────────────────────────────────

  /// Controls whether Goals (index 2) or Persona (index 3) comes first.
  /// Defaults to `'goals_first'` so the UI is never blocked.
  String _stepOrder = 'goals_first';

  // ── Collected state ────────────────────────────────────────────────────────

  /// Step 2 — nickname / preferred name.
  String _nickname = '';

  /// Step 3 or 4 — selected goal IDs (depending on step order flag).
  List<String> _selectedGoals = [];

  /// Step 3 or 4 — selected persona ID.
  String _selectedPersona = 'coach';

  /// Step 3 or 4 — proactivity level (0.0 = quiet, 1.0 = proactive).
  double _proactivity = 0.5;

  /// Step 5 — fitness level ID: 'beginner' | 'active' | 'athletic'.
  String? _fitnessLevel;

  /// Step 7 — morning briefing enabled.
  bool _morningBriefingEnabled = true;

  /// Step 7 — morning briefing time (default 08:00).
  TimeOfDay _morningBriefingTime = const TimeOfDay(hour: 8, minute: 0);

  /// Step 7 — smart activity reminders enabled.
  bool _smartRemindersEnabled = true;

  /// Step 7 — wellness check-in enabled.
  bool _wellnessCheckInEnabled = false;

  /// Step 8 — discovery source.
  String? _discoverySource;

  /// Whether the final submission call is in flight.
  bool _isSubmitting = false;

  // ── Page list ──────────────────────────────────────────────────────────────

  /// Returns the ordered list of 8 onboarding pages.
  List<Widget> get _pages {
    final goalsStep = GoalsStep(
      selectedGoals: _selectedGoals,
      onGoalsChanged: (goals) => setState(() => _selectedGoals = goals),
    );

    final personaStep = PersonaStep(
      selectedPersona: _selectedPersona,
      proactivity: _proactivity,
      onPersonaChanged: (p) => setState(() => _selectedPersona = p),
      onProactivityChanged: (v) => setState(() => _proactivity = v),
    );

    final step3 = _stepOrder == 'persona_first' ? personaStep : goalsStep;
    final step4 = _stepOrder == 'persona_first' ? goalsStep : personaStep;

    return [
      // Step 1 — Welcome (manages its own CTA, no bottom nav)
      WelcomeStep(onNext: _handleNext),

      // Step 2 — Name / Nickname
      NameStep(
        nickname: _nickname,
        onNicknameChanged: (v) => setState(() => _nickname = v),
      ),

      // Step 3 — Goals or Persona (flag-controlled)
      step3,

      // Step 4 — Persona or Goals (flag-controlled)
      step4,

      // Step 5 — Fitness Level
      FitnessLevelStep(
        selectedLevel: _fitnessLevel,
        onLevelChanged: (v) => setState(() => _fitnessLevel = v),
      ),

      // Step 6 — Connect Apps (Apple Health / Health Connect)
      const ConnectAppsStep(),

      // Step 7 — Notifications
      NotificationsStep(
        morningBriefingEnabled: _morningBriefingEnabled,
        morningBriefingTime: _morningBriefingTime,
        smartRemindersEnabled: _smartRemindersEnabled,
        wellnessCheckInEnabled: _wellnessCheckInEnabled,
        onMorningBriefingChanged: (v) =>
            setState(() => _morningBriefingEnabled = v),
        onMorningTimeChanged: (t) => setState(() => _morningBriefingTime = t),
        onSmartRemindersChanged: (v) =>
            setState(() => _smartRemindersEnabled = v),
        onWellnessCheckInChanged: (v) =>
            setState(() => _wellnessCheckInEnabled = v),
      ),

      // Step 8 — Discovery
      DiscoveryStep(
        selectedSource: _discoverySource,
        onSourceChanged: (s) => setState(() => _discoverySource = s),
      ),
    ];
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    ref.read(featureFlagServiceProvider).onboardingStepOrder().then((order) {
      if (mounted) setState(() => _stepOrder = order);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _handleNext() async {
    final analytics = ref.read(analyticsServiceProvider);

    analytics.capture(
      event: AnalyticsEvents.onboardingStepCompleted,
      properties: {'step': _currentPage + 1, 'total_steps': _totalPages},
    );

    // Step 2 = Name
    if (_currentPage == 1 && _nickname.isNotEmpty) {
      analytics.capture(
        event: 'nickname_entered',
        properties: {'has_nickname': true},
      );
    }

    // Goals step index depends on flag
    final goalsIndex = _stepOrder == 'persona_first' ? 3 : 2;
    if (_currentPage == goalsIndex) {
      analytics.capture(
        event: AnalyticsEvents.onboardingGoalsSelected,
        properties: {'goals_count': _selectedGoals.length},
      );
    }

    // Persona step index depends on flag
    final personaIndex = _stepOrder == 'persona_first' ? 2 : 3;
    if (_currentPage == personaIndex) {
      analytics.capture(
        event: AnalyticsEvents.onboardingPersonaSelected,
        properties: {
          'persona': _selectedPersona,
          'proactivity': _proactivityApiKey(_proactivity),
        },
      );
    }

    // Step 5 = Fitness Level (index 4)
    if (_currentPage == 4) {
      analytics.capture(
        event: 'fitness_level_selected',
        properties: {'fitness_level': _fitnessLevel ?? 'skipped'},
      );
    }

    // Step 7 = Notifications (index 6)
    if (_currentPage == 6) {
      analytics.capture(
        event: AnalyticsEvents.onboardingNotificationToggled,
        properties: {
          'morning_briefing': _morningBriefingEnabled,
          'smart_reminders': _smartRemindersEnabled,
          'checkin_reminder': _wellnessCheckInEnabled,
        },
      );
    }

    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _handleFinish();
    }
  }

  void _handleBack() {
    if (_currentPage > 0 && !_isSubmitting) {
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.onboardingStepBack,
        properties: {'from_step': _currentPage + 1},
      );
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Submission ─────────────────────────────────────────────────────────────

  Future<void> _handleFinish() async {
    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      final morningTime =
          '${_morningBriefingTime.hour.toString().padLeft(2, '0')}:'
          '${_morningBriefingTime.minute.toString().padLeft(2, '0')}';

      // PATCH all collected preferences in a single request.
      // `fitness_level` is a new field (v3.2). The backend ignores unknown
      // fields in the PATCH body, so this is safe until the field is added.
      final body = <String, dynamic>{
        'goals': _selectedGoals,
        'coach_persona': _personaApiKey[_selectedPersona] ?? 'gentle',
        'proactivity_level': _proactivityApiKey(_proactivity),
        'morning_briefing_time': morningTime,
        // Backend field is `checkin_reminder_enabled`
        'checkin_reminder_enabled': _wellnessCheckInEnabled,
      };
      // Only include fitness_level when the user actually selected one —
      // sending an empty string causes backend validation to reject the request.
      if (_fitnessLevel != null && _fitnessLevel!.isNotEmpty) {
        body['fitness_level'] = _fitnessLevel;
      }

      if (_nickname.isNotEmpty) {
        body['nickname'] = _nickname;
      }

      await apiClient.patch('/api/v1/preferences', body: body);

      // PostHog completion events
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.onboardingCompleted,
        properties: {
          'goals_count': _selectedGoals.length,
          'persona': _selectedPersona,
          'proactivity': _proactivityApiKey(_proactivity),
          'morning_briefing': _morningBriefingEnabled,
          'checkin_reminder_enabled': _wellnessCheckInEnabled,
          'fitness_level': _fitnessLevel ?? 'skipped',
          'has_nickname': _nickname.isNotEmpty,
          'discovery_source': _discoverySource ?? 'skipped',
        },
      );
      if (_discoverySource != null) {
        ref.read(analyticsServiceProvider).capture(
          event: AnalyticsEvents.onboardingDiscoverySource,
          properties: {'source': _discoverySource},
        );
      }

      // Mark onboarding complete and update nickname on user profile.
      await ref.read(userProfileProvider.notifier).update(
            onboardingComplete: true,
            nickname: _nickname.isNotEmpty ? _nickname : null,
          );

      if (!mounted) return;
      context.go(RouteNames.todayPath);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[OnboardingFlow] Save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save preferences. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ZuralogScaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: ZPatternOverlay(
              variant: ZPatternVariant.sage,
              opacity: 0.10,
            ),
          ),
          Column(
            children: [
              _OnboardingTopBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onBack:
                    (_currentPage > 0 && !_isSubmitting) ? _handleBack : null,
                onSkip:
                    (_currentPage > 0 && !_isSubmitting) ? _handleNext : null,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: _pages,
                ),
              ),
              if (_currentPage > 0)
                _OnboardingBottomNav(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  isSubmitting: _isSubmitting,
                  onBack: _handleBack,
                  onNext: _handleNext,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

/// Top bar: back arrow (left), morphing pill step dots (center), skip (right).
class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
    required this.onSkip,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        0,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppDimens.touchTargetMin,
            height: AppDimens.touchTargetMin,
            child: onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: colors.textSecondary,
                    onPressed: onBack,
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),

          Expanded(
            child: Center(
              child: _StepDots(
                currentPage: currentPage,
                totalPages: totalPages,
              ),
            ),
          ),

          SizedBox(
            width: AppDimens.touchTargetMin + AppDimens.spaceMd,
            height: AppDimens.touchTargetMin,
            child: (onSkip != null && currentPage > 0)
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                      ),
                    ),
                    child: const Text('Skip'),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Step Dots ─────────────────────────────────────────────────────────────────

/// Morphing pill dot indicators for 8-step onboarding flow.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            color: isActive ? colors.primary : colors.surfaceRaised,
          ),
        );
      }),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

/// Back / Next (or Finish) button row shown for steps 2–8.
class _OnboardingBottomNav extends StatelessWidget {
  const _OnboardingBottomNav({
    required this.currentPage,
    required this.totalPages,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLastPage = currentPage == totalPages - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: ZButton(
              label: 'Back',
              variant: ZButtonVariant.secondary,
              size: ZButtonSize.medium,
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: ZButton(
              label: isLastPage ? 'Finish' : 'Next',
              isLoading: isSubmitting,
              size: ZButtonSize.medium,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}
