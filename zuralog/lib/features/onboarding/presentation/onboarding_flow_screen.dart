/// Zuralog — 6-Step Onboarding Flow Screen.
///
/// Replaces the legacy [ProfileQuestionnaireScreen] (3-step form) with a
/// richer, multi-step onboarding experience shown once after registration.
///
/// **Steps:**
///   1. Welcome — animated headline + CTA
///   2. Goals — multi-select health goal grid
///   3. AI Persona — persona card selection + proactivity toggle
///   4. Connect Apps — integration tiles (informational; connect later in Settings)
///   5. Notifications — morning briefing, smart reminders, wellness check-in
///   6. Discovery — "Where did you hear about us?" (PostHog event)
///
/// On completion:
///   - PATCHes `/api/v1/preferences` with all collected selections.
///   - Calls [UserProfileNotifier.update] with `onboardingComplete: true`.
///   - Navigates to [RouteNames.dashboardPath] (Today Feed).
///
/// **Widget type:** [ConsumerStatefulWidget] — Riverpod ref for profile
/// update, analytics, and API client; local [PageController] for the PageView.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/presentation/steps/connect_apps_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/discovery_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/goals_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/notifications_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/persona_step.dart';
import 'package:zuralog/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

/// 6-step onboarding flow shown once after a new user registers.
///
/// Collects goals, AI persona preference, app connections, notification
/// preferences, and discovery source before marking onboarding complete.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingFlowScreen].
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

// ── Persona ID mapping ────────────────────────────────────────────────────────

/// Maps the UI persona IDs used in [PersonaStep] to the API enum values
/// accepted by `/api/v1/preferences` (`CoachPersona` enum on the backend).
const Map<String, String> _personaApiKey = {
  'motivator': 'toughLove',
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

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  // ── Page controller ────────────────────────────────────────────────────────

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Step pages (single source of truth for page count) ────────────────────

  late final List<Widget> _pages = [
    // Step 1 — Welcome (manages its own CTA)
    WelcomeStep(onNext: _handleNext),

    // Step 2 — Goals
    GoalsStep(
      selectedGoals: _selectedGoals,
      onGoalsChanged: (goals) => setState(() => _selectedGoals = goals),
    ),

    // Step 3 — AI Persona
    PersonaStep(
      selectedPersona: _selectedPersona,
      proactivity: _proactivity,
      onPersonaChanged: (p) => setState(() => _selectedPersona = p),
      onProactivityChanged: (v) => setState(() => _proactivity = v),
    ),

    // Step 4 — Connect Apps (informational)
    const ConnectAppsStep(),

    // Step 5 — Notifications
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

    // Step 6 — Discovery
    DiscoveryStep(
      selectedSource: _discoverySource,
      onSourceChanged: (s) => setState(() => _discoverySource = s),
    ),
  ];

  // ── Collected state from each step ────────────────────────────────────────

  /// Step 2 — selected goal IDs.
  List<String> _selectedGoals = [];

  /// Step 3 — selected persona ID (UI key: 'motivator' | 'analyst' | 'coach').
  String _selectedPersona = 'coach';

  /// Step 3 — proactivity level (0.0 = quiet, 1.0 = proactive).
  double _proactivity = 0.5;

  /// Step 5 — morning briefing enabled.
  bool _morningBriefingEnabled = true;

  /// Step 5 — morning briefing time (default 08:00).
  TimeOfDay _morningBriefingTime = const TimeOfDay(hour: 8, minute: 0);

  /// Step 5 — smart activity reminders enabled.
  bool _smartRemindersEnabled = true;

  /// Step 5 — wellness check-in enabled.
  bool _wellnessCheckInEnabled = false;

  /// Step 6 — discovery source.
  String? _discoverySource;

  /// Whether the final submission call is in flight.
  bool _isSubmitting = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _handleNext() async {
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

      // 1. Persist all collected onboarding preferences in a single PATCH.
      final morningTime =
          '${_morningBriefingTime.hour.toString().padLeft(2, '0')}:'
          '${_morningBriefingTime.minute.toString().padLeft(2, '0')}';

      await apiClient.patch(
        '/api/v1/preferences',
        body: {
          'goals': _selectedGoals,
          'coach_persona': _personaApiKey[_selectedPersona] ?? 'gentle',
          'proactivity_level': _proactivityApiKey(_proactivity),
          'morning_briefing_enabled': _morningBriefingEnabled,
          'morning_briefing_time': morningTime,
          'smart_reminders_enabled': _smartRemindersEnabled,
          'wellness_check_in_enabled': _wellnessCheckInEnabled,
        },
      );

      // 2. Fire PostHog discovery event (only on successful completion, once).
      if (_discoverySource != null) {
        ref.read(analyticsServiceProvider).capture(
          event: 'onboarding_discovery',
          properties: {'source': _discoverySource},
        );
      }

      // 3. Mark onboarding complete on the user profile.
      await ref.read(userProfileProvider.notifier).update(
            onboardingComplete: true,
          );

      if (!mounted) return;
      context.go(RouteNames.dashboardPath);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[OnboardingFlow] Save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save preferences. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: back button + step dots ──────────────────────────
            _OnboardingTopBar(
              currentPage: _currentPage,
              totalPages: _pages.length,
              // Disable back navigation while submission is in flight.
              onBack: (_currentPage > 0 && !_isSubmitting) ? _handleBack : null,
            ),

            // ── Page content ──────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: _pages,
              ),
            ),

            // ── Bottom navigation ─────────────────────────────────────────
            // Welcome step manages its own CTA; other steps show Back/Next.
            if (_currentPage > 0)
              _OnboardingBottomNav(
                currentPage: _currentPage,
                totalPages: _pages.length,
                isSubmitting: _isSubmitting,
                onBack: _handleBack,
                onNext: _handleNext,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

/// Top bar showing an optional back arrow and the dot step indicator.
class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          // Back button placeholder — always takes space to keep dots centred.
          SizedBox(
            width: AppDimens.touchTargetMin,
            height: AppDimens.touchTargetMin,
            child: onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: onBack,
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),

          // Step dot indicator — centred in remaining space.
          Expanded(
            child: Center(
              child: _StepDots(
                currentPage: currentPage,
                totalPages: totalPages,
              ),
            ),
          ),

          // Right spacer (mirrors left button width for symmetry).
          const SizedBox(width: AppDimens.touchTargetMin),
        ],
      ),
    );
  }
}

// ── Step Dots ─────────────────────────────────────────────────────────────────

/// Animated dot row indicating progress through the onboarding steps.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.circular(3),
            color: isActive ? AppColors.primary : AppColors.borderDark,
          ),
        );
      }),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

/// Back / Next (or Finish) button row shown for steps 2–6.
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
            child: SecondaryButton(label: 'Back', onPressed: onBack),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: PrimaryButton(
              label: isLastPage ? 'Finish' : 'Next',
              isLoading: isSubmitting,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}
