/// Zuralog — Phase 3 Personalization Wizard (v2.0).
///
/// Replaces [OnboardingFlowScreen] (old 8-step wizard).
///
/// 6 content steps + 1 done screen:
///   1  Name
///   2  Goals
///   3  Fitness level
///   4  Connect health data
///   5  Notifications
///   6  Discovery source
///   7  Done (no step counter — just a "enter the app" screen)
///
/// On completion (after step 6) the wizard:
///   1. PATCHes /api/v1/preferences with all collected data.
///   2. Marks onboarding complete via [userProfileProvider].
///   3. Navigates to step 7 (done screen), never back to the wizard.
///   4. "Open ZuraLog" button on done screen navigates to [RouteNames.todayPath].
///
/// Backend fitness_level mapping (via [levelToBackendValue]):
///   just_starting / casual -> beginner
///   consistent             -> active
///   advanced               -> athletic
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/presentation/steps/p3_steps.dart';
import 'package:zuralog/features/onboarding/presentation/tour/tour_widgets.dart';
import 'package:zuralog/features/onboarding/providers/onboarding_tour_providers.dart';

// ── Total wizard steps (shown in progress bar denominator) ────────────────────

/// Steps 0-5 are the "answering" steps. Step 6 is the done screen.
/// Progress bar fills from 0 to 1 over steps 0-5 (index 0 = "1 of 6").
const int _kWizardSteps = 7; // total PageView pages (including done screen)
const int _kContentSteps = 6; // steps shown in progress bar

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

/// 7-step personalization wizard shown once after a new user registers.
///
/// Replaces the old [OnboardingFlowScreen] 8-step wizard. All backend wiring
/// (PATCH /api/v1/preferences, userProfileProvider.update) is preserved.
class PersonalizationFlowScreen extends ConsumerStatefulWidget {
  const PersonalizationFlowScreen({super.key});

  @override
  ConsumerState<PersonalizationFlowScreen> createState() =>
      _PersonalizationFlowScreenState();
}

class _PersonalizationFlowScreenState
    extends ConsumerState<PersonalizationFlowScreen> {
  // ── Page controller ────────────────────────────────────────────────────────

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Collected state ────────────────────────────────────────────────────────

  /// Step 1 — preferred name / nickname.
  String _name = '';

  /// Step 2 — selected focus pillar IDs.
  /// Pre-populated from the tour's pillar selection.
  List<String> _selectedGoals = [];

  /// Step 3 — selected level option ID (see [_kLevelOptions] in p3_steps.dart).
  String? _level;

  /// Step 6 — morning summary enabled.
  bool _morningEnabled = true;

  /// Step 6 — weekly insights enabled.
  bool _weeklyEnabled = true;

  /// Step 6 — real-time nudges enabled.
  bool _nudgesEnabled = false;

  /// Step 7 — discovery source string.
  String? _source;

  /// True while the PATCH call is in flight.
  bool _submitting = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Pre-populate goals from the tour selection (best-effort; fine to be empty).
    _selectedGoals = List<String>.from(
      ref.read(selectedTourPillarsProvider),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _advance() async {
    if (_submitting) return;
    final analytics = ref.read(analyticsServiceProvider);

    analytics.capture(
      event: AnalyticsEvents.onboardingStepCompleted,
      properties: {
        'step': _currentPage + 1,
        'total_steps': _kContentSteps,
      },
    );

    switch (_currentPage) {
      case 0: // Name
        if (_name.isNotEmpty) {
          analytics.capture(
            event: 'nickname_entered',
            properties: {'has_nickname': true},
          );
        }
      case 1: // Goals
        analytics.capture(
          event: AnalyticsEvents.onboardingGoalsSelected,
          properties: {'goals_count': _selectedGoals.length},
        );
      case 2: // Level
        analytics.capture(
          event: 'fitness_level_selected',
          properties: {'fitness_level': levelToBackendValue(_level)},
        );
      case 4: // Notifications
        analytics.capture(
          event: AnalyticsEvents.onboardingNotificationToggled,
          properties: {
            'morning_briefing': _morningEnabled,
            'weekly_insights': _weeklyEnabled,
            'nudges': _nudgesEnabled,
          },
        );
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentPage > 0 && !_submitting) {
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

  /// Called after the user taps "Finish" on the final content step (step 7).
  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final analytics = ref.read(analyticsServiceProvider);

      final body = <String, dynamic>{
        'goals': _selectedGoals,
        // Proactivity defaults to medium when not explicitly set in the new flow.
        'proactivity_level': 'medium',
        'morning_briefing_enabled': _morningEnabled,
        // Morning briefing at 07:30 is the default; the user can change it in Settings.
        if (_morningEnabled) 'morning_briefing_time': '07:30',
        // checkin_reminder_enabled maps to the weekly insights toggle in this flow.
        'checkin_reminder_enabled': _weeklyEnabled,
        'nudges_enabled': _nudgesEnabled,
        if (_source != null) 'discovery_source': _source,
      };

      // Only send fitness_level when a selection was actually made to avoid
      // triggering backend validation on an empty string.
      if (_level != null && _level!.isNotEmpty) {
        body['fitness_level'] = levelToBackendValue(_level);
      }

      await apiClient.patch('/api/v1/preferences', body: body);

      // Analytics completion event.
      analytics.capture(
        event: AnalyticsEvents.onboardingCompleted,
        properties: {
          'goals_count': _selectedGoals.length,
          'morning_briefing': _morningEnabled,
          'weekly_insights': _weeklyEnabled,
          'nudges': _nudgesEnabled,
          'fitness_level': levelToBackendValue(_level),
          'has_name': _name.isNotEmpty,
          'discovery_source': _source ?? 'skipped',
        },
      );

      if (_source != null) {
        analytics.capture(
          event: AnalyticsEvents.onboardingDiscoverySource,
          properties: {'source': _source},
        );
      }

      // Mark onboarding complete and persist the user's name.
      await ref.read(userProfileProvider.notifier).update(
            onboardingComplete: true,
            nickname: _name.trim().isNotEmpty ? _name.trim() : null,
          );

      if (!mounted) return;

      // Navigate to the done screen (step 8 in PageView index).
      await _pageController.animateToPage(
        _kWizardSteps - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[PersonalizationFlow] Save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Something went wrong saving your preferences. Please try again.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          // Animated topo background
          const TopoBG(
            opacity: 0.08,
            seed: 'p3',
            animate: true,
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                _P3TopBar(
                  currentPage: _currentPage,
                  totalContentSteps: _kContentSteps,
                  onBack: (_currentPage > 0 && _currentPage < _kWizardSteps - 1)
                      ? _goBack
                      : null,
                  onSkip: (_currentPage > 0 &&
                          _currentPage < _kWizardSteps - 2 &&
                          !_submitting)
                      ? _advance
                      : null,
                ),

                // ── Step pages ───────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemCount: _kWizardSteps,
                    itemBuilder: (context, index) => _buildPage(index),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay while submitting
          if (_submitting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return P3NameStep(
          name: _name,
          onChanged: (v) => setState(() => _name = v),
          onNext: _advance,
        );
      case 1:
        return P3GoalsStep(
          selectedGoals: _selectedGoals,
          onChanged: (goals) => setState(() => _selectedGoals = goals),
          onNext: _advance,
        );
      case 2:
        return P3LevelStep(
          level: _level,
          onChanged: (v) => setState(() => _level = v),
          onNext: _advance,
        );
      case 3:
        return P3ConnectStep(onNext: _advance);
      case 4:
        return P3NotifsStep(
          morningEnabled: _morningEnabled,
          weeklyEnabled: _weeklyEnabled,
          nudgesEnabled: _nudgesEnabled,
          onMorningChanged: (v) => setState(() => _morningEnabled = v),
          onWeeklyChanged: (v) => setState(() => _weeklyEnabled = v),
          onNudgesChanged: (v) => setState(() => _nudgesEnabled = v),
          onNext: _advance,
        );
      case 5:
        return P3SourceStep(
          source: _source,
          onChanged: (v) => setState(() => _source = v),
          onFinish: _submit,
        );
      case 6:
        return P3DoneStep(
          name: _name,
          onEnterApp: () => context.go(RouteNames.todayPath),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top bar
// ═══════════════════════════════════════════════════════════════════════════════

/// Back chevron (left) + animated progress bar (center) + Skip (right).
///
/// Hidden in its entirety on the done screen (handled by the orchestrator
/// passing null for both [onBack] and [onSkip] and the bar being at 100%).
class _P3TopBar extends StatelessWidget {
  const _P3TopBar({
    required this.currentPage,
    required this.totalContentSteps,
    required this.onBack,
    required this.onSkip,
  });

  final int currentPage;
  final int totalContentSteps;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    // Progress goes from 0 → 1 over the 7 content steps.
    // On the done screen (page 7) we show a full bar.
    final progress = currentPage >= totalContentSteps
        ? 1.0
        : (currentPage + 1) / totalContentSteps;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Back button
            SizedBox(
              width: 36,
              height: 36,
              child: onBack != null
                  ? GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 28,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            // Progress bar
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 3,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Skip button
            SizedBox(
              width: 44,
              height: 36,
              child: onSkip != null
                  ? GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
