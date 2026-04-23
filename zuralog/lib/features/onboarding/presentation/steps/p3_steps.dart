/// Zuralog — Phase 3 Personalization Wizard: All step widgets.
///
/// Each step is a self-contained widget that receives its current state
/// and callbacks from [PersonalizationFlowScreen]. The orchestrator owns
/// all mutable state; these widgets are purely presentational.
///
/// Step index -> purpose:
///   0  P3NameStep      — preferred name
///   1  P3GoalsStep     — confirm / pick focus pillars
///   2  P3LevelStep     — pick fitness level
///   3  P3ConnectStep   — connect health data source
///   4  P3NotifsStep    — notification preferences
///   5  P3SourceStep    — discovery source (last step before submit)
///   6  P3DoneStep      — confirmation / enter app
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/onboarding/presentation/tour/tour_widgets.dart';

// ── Shared layout helpers ─────────────────────────────────────────────────────

/// Standard horizontal padding used on every step's content.
const double _kHPad = 24.0;

/// Common step label style: "N OF 6 . SUBTITLE"
TextStyle _labelStyle() => const TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      color: AppColors.primary,
    );

/// Large heading on every step.
TextStyle _headingStyle() => const TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 28,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.8,
      color: Colors.white,
      height: 1.2,
    );

/// Secondary/sub-text on steps.
TextStyle _bodyStyle() => TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: Colors.white.withValues(alpha: 0.55),
      height: 1.5,
    );

// ── Selectable row — used by coach + level steps ──────────────────────────────

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Name
// ═══════════════════════════════════════════════════════════════════════════════

/// Step 1 of 6 — asks the user what to call them.
class P3NameStep extends StatefulWidget {
  const P3NameStep({
    super.key,
    required this.name,
    required this.onChanged,
    required this.onNext,
  });

  final String name;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  @override
  State<P3NameStep> createState() => _P3NameStepState();
}

class _P3NameStepState extends State<P3NameStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _ctrl.text.trim();
    final canContinue = trimmed.length >= 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          RevealAnimation(
            child: Text('1 OF 6', style: _labelStyle()),
          ),
          const SizedBox(height: 12),
          RevealAnimation(
            delay: const Duration(milliseconds: 80),
            child: Text(
              "Let's start with your name.",
              style: _headingStyle().copyWith(fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          RevealAnimation(
            delay: const Duration(milliseconds: 140),
            child: Text(
              'Your coach will use it when we talk.',
              style: _bodyStyle(),
            ),
          ),
          const SizedBox(height: 40),

          // Underline text field with a live confirm-check icon on the right.
          RevealAnimation(
            delay: const Duration(milliseconds: 220),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    cursorColor: AppColors.primary,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: -0.4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      filled: false,
                      contentPadding: const EdgeInsets.only(bottom: 8),
                    ),
                    onChanged: (v) {
                      widget.onChanged(v);
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      if (canContinue) widget.onNext();
                    },
                  ),
                ),
                // Tiny confirmation tick — fades in when the name is valid.
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 14),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    opacity: canContinue ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      scale: canContinue ? 1 : 0.6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF1A2E22),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gentle greeting that appears once the user has entered a valid name.
          const SizedBox(height: 20),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            opacity: canContinue ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              offset: canContinue ? Offset.zero : const Offset(0, 0.2),
              child: Text(
                canContinue ? 'Nice to meet you, $trimmed.' : '',
                style: _bodyStyle().copyWith(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),
          RevealAnimation(
            delay: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: TourPrimaryButton(
                label: 'Continue',
                disabled: !canContinue,
                onTap: canContinue ? widget.onNext : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Goals
// ═══════════════════════════════════════════════════════════════════════════════

/// Step 2 of 6 — confirm or select health focus pillars.
class P3GoalsStep extends StatelessWidget {
  const P3GoalsStep({
    super.key,
    required this.selectedGoals,
    required this.onChanged,
    required this.onNext,
  });

  final List<String> selectedGoals;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onNext;

  void _toggle(String id) {
    final next = List<String>.from(selectedGoals);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    // Show all 6 pillars as selectable rows. Pre-selected from tour.
    final allPillars = kPillars.values.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('2 OF 6  ·  YOUR FOCUS', style: _labelStyle()),
          const SizedBox(height: 12),
          Text('We will focus on what you chose.', style: _headingStyle()),
          const SizedBox(height: 24),

          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: allPillars.length,
              itemBuilder: (context, i) {
                final pillar = allPillars[i];
                final isSelected = selectedGoals.contains(pillar.id);

                return _SelectableRow(
                  selected: isSelected,
                  onTap: () => _toggle(pillar.id),
                  child: Row(
                    children: [
                      // Color square with icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: pillar.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: PillarIcon(pillar: pillar.id, size: 20, color: pillar.color),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pillar.name,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pillar.subtitle,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: AppColors.textOnSageDark,
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: TourPrimaryButton(
              label: 'Confirm. Continue',
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Fitness Level
// ═══════════════════════════════════════════════════════════════════════════════

/// A fitness level option shown in [P3LevelStep].
class _LevelOption {
  const _LevelOption({
    required this.id,
    required this.label,
    required this.backendValue,
    required this.description,
  });

  final String id;
  final String label;
  final String backendValue; // one of: beginner, active, athletic
  final String description;
}

const _kLevelOptions = [
  _LevelOption(id: 'just_starting', label: 'Just starting',  backendValue: 'beginner', description: 'New to regular exercise'),
  _LevelOption(id: 'casual',        label: 'Casual',          backendValue: 'beginner', description: 'Active a few times a week'),
  _LevelOption(id: 'consistent',    label: 'Consistent',      backendValue: 'active',   description: 'Regular training routine'),
  _LevelOption(id: 'advanced',      label: 'Advanced',        backendValue: 'athletic', description: 'Competitive or high-volume athlete'),
];

/// Step 3 of 6 — how active is the user, honestly?
class P3LevelStep extends StatelessWidget {
  const P3LevelStep({
    super.key,
    required this.level,
    required this.onChanged,
    required this.onNext,
  });

  /// The selected option ID (e.g. 'just_starting'), not the backend value.
  final String? level;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('3 OF 6', style: _labelStyle()),
          const SizedBox(height: 12),
          Text('How active are you, honestly?', style: _headingStyle()),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: _kLevelOptions.map((opt) {
                final isSelected = level == opt.id;
                return _SelectableRow(
                  selected: isSelected,
                  onTap: () => onChanged(opt.id),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              opt.description,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.circle,
                                size: 8,
                                color: AppColors.textOnSageDark,
                              )
                            : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: TourPrimaryButton(
              label: 'Continue',
              disabled: level == null,
              onTap: level != null ? onNext : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns the backend fitness_level value for a given UI option ID.
/// Falls back to 'beginner' if the ID is not recognized.
String levelToBackendValue(String? optionId) {
  return _kLevelOptions
      .cast<_LevelOption?>()
      .firstWhere((o) => o!.id == optionId, orElse: () => null)
      ?.backendValue ?? 'beginner';
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 4 — Connect Health Data
// ═══════════════════════════════════════════════════════════════════════════════

/// Step 4 of 6 — connect Apple Health or Health Connect.
class P3ConnectStep extends ConsumerWidget {
  const P3ConnectStep({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsState = ref.watch(integrationsProvider);

    final healthId = Platform.isIOS ? 'apple_health' : 'google_health_connect';
    final healthName = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final healthIcon = Platform.isIOS
        ? Icons.favorite_rounded
        : Icons.health_and_safety_rounded;
    final healthColor =
        Platform.isIOS ? AppColors.categoryHeart : AppColors.categoryActivity;

    final healthModel = integrationsState.integrations
        .cast<IntegrationModel?>()
        .firstWhere((i) => i!.id == healthId, orElse: () => null);
    final healthStatus = healthModel?.status ?? IntegrationStatus.available;
    final isConnected = healthStatus == IntegrationStatus.connected;
    final isConnecting = healthStatus == IntegrationStatus.syncing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('4 OF 6', style: _labelStyle()),
          const SizedBox(height: 12),
          Text('Pull in your health data.', style: _headingStyle()),
          const SizedBox(height: 8),
          Text(
            'We never share or sell. Disconnect anytime.',
            style: _bodyStyle(),
          ),
          const SizedBox(height: 28),

          // Connect card
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isConnected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: healthColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(healthIcon, size: 26, color: healthColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                healthName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Platform.isIOS
                                    ? 'Sync from HealthKit automatically'
                                    : 'Sync from Android Health Connect',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Connected',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ConnectBullet(icon: Icons.sync_rounded, text: 'Background sync — always current'),
                    const SizedBox(height: 8),
                    _ConnectBullet(icon: Icons.insights_rounded, text: 'AI-powered insights from real data'),
                    const SizedBox(height: 8),
                    _ConnectBullet(icon: Icons.lock_outline_rounded, text: 'Private, never shared or sold'),
                    const SizedBox(height: 20),
                    if (!isConnected)
                      GestureDetector(
                        onTap: isConnecting
                            ? null
                            : () => ref
                                .read(integrationsProvider.notifier)
                                .connect(healthId, context),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isConnecting
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isConnecting) ...[
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                isConnecting
                                    ? 'Connecting...'
                                    : 'Connect $healthName',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isConnecting
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : AppColors.textOnSageDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: TourPrimaryButton(
              label: isConnected ? 'Continue' : 'Skip for now',
              onTap: onNext,
              color: isConnected ? AppColors.primary : Colors.white.withValues(alpha: 0.10),
              textColor: isConnected ? AppColors.textOnSageDark : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectBullet extends StatelessWidget {
  const _ConnectBullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 5 — Notifications
// ═══════════════════════════════════════════════════════════════════════════════

/// Step 5 of 6 — choose notification preferences.
class P3NotifsStep extends StatelessWidget {
  const P3NotifsStep({
    super.key,
    required this.morningEnabled,
    required this.weeklyEnabled,
    required this.nudgesEnabled,
    required this.onMorningChanged,
    required this.onWeeklyChanged,
    required this.onNudgesChanged,
    required this.onNext,
  });

  final bool morningEnabled;
  final bool weeklyEnabled;
  final bool nudgesEnabled;
  final ValueChanged<bool> onMorningChanged;
  final ValueChanged<bool> onWeeklyChanged;
  final ValueChanged<bool> onNudgesChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('5 OF 6  ·  NOTIFICATIONS', style: _labelStyle()),
          const SizedBox(height: 12),
          Text('How often should we reach out?', style: _headingStyle()),
          const SizedBox(height: 28),

          _NotifRow(
            title: 'Morning summary',
            subtitle: '7:30am every day',
            value: morningEnabled,
            onChanged: onMorningChanged,
          ),
          const SizedBox(height: 14),
          _NotifRow(
            title: 'Weekly insights',
            subtitle: 'Sunday evenings',
            value: weeklyEnabled,
            onChanged: onWeeklyChanged,
          ),
          const SizedBox(height: 14),
          _NotifRow(
            title: 'Real-time nudges',
            subtitle: 'Hydration, bedtime, movement',
            value: nudgesEnabled,
            onChanged: onNudgesChanged,
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: TourPrimaryButton(
              label: 'Continue',
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _PillToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// iOS-style pill toggle: 44x26, sage when on, white dot.
class _PillToggle extends StatelessWidget {
  const _PillToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.14),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 6 — Discovery Source
// ═══════════════════════════════════════════════════════════════════════════════

const _kSources = [
  'Friend or family',
  'App Store',
  'Instagram',
  'TikTok',
  'Podcast',
  'Doctor',
  'Somewhere else',
];

/// Step 6 of 6 — where did the user find ZuraLog?
class P3SourceStep extends StatelessWidget {
  const P3SourceStep({
    super.key,
    required this.source,
    required this.onChanged,
    required this.onFinish,
  });

  final String? source;
  final ValueChanged<String> onChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('6 OF 6  ·  LAST ONE', style: _labelStyle()),
          const SizedBox(height: 12),
          Text('Where did you find us?', style: _headingStyle()),
          const SizedBox(height: 28),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kSources.map((s) {
                  final isSelected = source == s;
                  return GestureDetector(
                    onTap: () => onChanged(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.14),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          color: isSelected
                              ? AppColors.textOnSageDark
                              : Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: TourPrimaryButton(
              label: 'Finish',
              disabled: source == null,
              onTap: source != null ? onFinish : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP 7 — Done
// ═══════════════════════════════════════════════════════════════════════════════

/// Final step — celebratory confirmation with a breathing checkmark.
class P3DoneStep extends StatefulWidget {
  const P3DoneStep({
    super.key,
    required this.name,
    required this.onEnterApp,
  });

  final String name;
  final VoidCallback onEnterApp;

  @override
  State<P3DoneStep> createState() => _P3DoneStepState();
}

class _P3DoneStepState extends State<P3DoneStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathe;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.trim().isNotEmpty ? widget.name.trim() : 'there';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHPad),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Breathing checkmark circle
          RevealAnimation(
            duration: const Duration(milliseconds: 900),
            child: AnimatedBuilder(
              animation: _scale,
              builder: (_, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: AppColors.textOnSageDark,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          RevealAnimation(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'Welcome, $displayName.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 48,
                fontWeight: FontWeight.w300,
                letterSpacing: -2,
                color: AppColors.primary,
                height: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 16),

          RevealAnimation(
            delay: const Duration(milliseconds: 360),
            child: Text(
              'ZuraLog is ready. Let\'s open your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.70),
                height: 1.5,
              ),
            ),
          ),

          const Spacer(flex: 3),

          RevealAnimation(
            delay: const Duration(milliseconds: 500),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: TourPrimaryButton(
                label: 'Open ZuraLog',
                onTap: widget.onEnterApp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
