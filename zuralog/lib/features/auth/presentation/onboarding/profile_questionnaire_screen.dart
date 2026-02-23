/// Zuralog Edge Agent — Profile Questionnaire Screen.
///
/// A 3-step onboarding questionnaire shown immediately after a new user
/// registers. Collects the information needed to personalise the AI experience:
///
///   - **Step 1 — Name**: Display name (full name) and nickname (what the AI
///     calls you).
///   - **Step 2 — Birthday**: Date of birth via [showDatePicker] (Material style,
///     consistent with the rest of the app which is Material-based).
///   - **Step 3 — Gender**: Selection via radio-style option tiles with the
///     values: "Male", "Female", "Non-binary", "Prefer not to say".
///
/// After the final step the notifier's [UserProfileNotifier.update] method is
/// called with all collected data and `onboardingComplete: true`, then the
/// user is navigated to the dashboard.
///
/// **Widget type:** [ConsumerStatefulWidget] — uses Riverpod [ref] for the
/// profile update call and local state for multi-step form management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Total number of steps in the questionnaire.
const int _totalSteps = 3;

/// Gender options presented to the user in Step 3.
const List<String> _genderOptions = [
  'Male',
  'Female',
  'Non-binary',
  'Prefer not to say',
];

/// Earliest selectable birthday (100 years ago).
DateTime get _birthdayFirst =>
    DateTime(DateTime.now().year - 100, 1, 1);

/// Latest selectable birthday (13 years ago — minimum age).
DateTime get _birthdayLast =>
    DateTime(DateTime.now().year - 13, DateTime.now().month, DateTime.now().day);

// ── Screen ────────────────────────────────────────────────────────────────────

/// Multi-step profile questionnaire shown once after initial registration.
///
/// Collects display name, nickname, birthday, and gender before marking
/// [UserProfile.onboardingComplete] as `true` and navigating to the dashboard.
class ProfileQuestionnaireScreen extends ConsumerStatefulWidget {
  /// Creates a [ProfileQuestionnaireScreen].
  const ProfileQuestionnaireScreen({super.key});

  @override
  ConsumerState<ProfileQuestionnaireScreen> createState() =>
      _ProfileQuestionnaireScreenState();
}

/// State for [ProfileQuestionnaireScreen].
///
/// Manages the current step index, form key, collected field values, and
/// the async submission flow.
class _ProfileQuestionnaireScreenState
    extends ConsumerState<ProfileQuestionnaireScreen> {
  // ── Step tracking ──────────────────────────────────────────────────────────

  /// Zero-based index of the currently displayed step (0–2).
  int _currentStep = 0;

  // ── Form state ─────────────────────────────────────────────────────────────

  /// Form key used to validate Step 1 fields.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controller for the "Display name" text field (Step 1).
  final TextEditingController _displayNameController = TextEditingController();

  /// Controller for the "Nickname" text field (Step 1).
  final TextEditingController _nicknameController = TextEditingController();

  /// Selected date of birth (Step 2). `null` means not yet chosen.
  DateTime? _birthday;

  /// Selected gender string (Step 3). `null` means not yet chosen.
  String? _gender;

  /// Whether the final submission network call is in flight.
  bool _isSubmitting = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Advances to the next step (or submits on the final step).
  ///
  /// Step 1 runs form validation before advancing.
  /// Step 2 requires a birthday to be selected.
  /// Step 3 triggers the profile update.
  Future<void> _handleNext() async {
    switch (_currentStep) {
      case 0:
        // Validate display name field (required).
        if (!(_formKey.currentState?.validate() ?? false)) return;
        setState(() => _currentStep = 1);
      case 1:
        // Birthday is optional — advance even if not selected.
        setState(() => _currentStep = 2);
      case 2:
        // Final step — submit and navigate.
        await _handleSubmit();
    }
  }

  /// Returns to the previous step.
  ///
  /// Should only be callable when [_currentStep] > 0.
  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ── Submission ─────────────────────────────────────────────────────────────

  /// Calls [UserProfileNotifier.update] with all collected data.
  ///
  /// Sets [onboardingComplete] to `true` and navigates to the dashboard on
  /// success. Shows a [SnackBar] on failure.
  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      await ref.read(userProfileProvider.notifier).update(
            displayName: _displayNameController.text.trim().isEmpty
                ? null
                : _displayNameController.text.trim(),
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            birthday: _birthday,
            gender: _gender,
            onboardingComplete: true,
          );

      if (!mounted) return;
      context.go(RouteNames.dashboardPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save profile. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  /// Opens the Material date picker and updates [_birthday] on selection.
  Future<void> _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: _birthdayFirst,
      lastDate: _birthdayLast,
      helpText: 'Select your birthday',
      builder: (context, child) {
        // Apply theme colours to the date picker.
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.primaryButtonText,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // Show back button only after step 1.
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Back',
                onPressed: _handleBack,
              )
            : null,
        title: SvgPicture.asset(
          'assets/images/zuralog_logo.svg',
          height: 28,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Progress indicator ───────────────────────────────────────
              _ProgressHeader(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
              ),

              const SizedBox(height: AppDimens.spaceXl),

              // ── Step content ─────────────────────────────────────────────
              Expanded(
                child: _buildStep(context),
              ),

              const SizedBox(height: AppDimens.spaceLg),

              // ── Navigation buttons ───────────────────────────────────────
              _NavigationButtons(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
                isSubmitting: _isSubmitting,
                onBack: _currentStep > 0 ? _handleBack : null,
                onNext: _handleNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the content widget for the current step.
  Widget _buildStep(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _Step1Name(
          formKey: _formKey,
          displayNameController: _displayNameController,
          nicknameController: _nicknameController,
        );
      case 1:
        return _Step2Birthday(
          birthday: _birthday,
          onSelectBirthday: _selectBirthday,
        );
      case 2:
        return _Step3Gender(
          selectedGender: _gender,
          onGenderSelected: (gender) => setState(() => _gender = gender),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Progress Header ────────────────────────────────────────────────────────────

/// Displays the current step number and a linear progress bar.
///
/// Shows "Step X of Y" text above a segmented progress track.
class _ProgressHeader extends StatelessWidget {
  /// Creates a [_ProgressHeader].
  const _ProgressHeader({
    required this.currentStep,
    required this.totalSteps,
  });

  /// Zero-based index of the current step.
  final int currentStep;

  /// Total number of steps.
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Segmented progress track — one filled segment per completed step.
        Row(
          children: List.generate(totalSteps, (index) {
            final isComplete = index <= currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 4,
                margin: EdgeInsets.only(
                  right: index < totalSteps - 1 ? AppDimens.spaceXs : 0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isComplete
                      ? AppColors.primary
                      : AppColors.borderLight,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Navigation Buttons ────────────────────────────────────────────────────────

/// Row containing the "Back" and "Next"/"Finish" navigation buttons.
///
/// Back is hidden on step 0 (disabled via `null` callback).
/// Next becomes "Finish" on the final step.
class _NavigationButtons extends StatelessWidget {
  /// Creates [_NavigationButtons].
  const _NavigationButtons({
    required this.currentStep,
    required this.totalSteps,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
  });

  /// Zero-based current step index.
  final int currentStep;

  /// Total number of steps.
  final int totalSteps;

  /// Whether the async submission is in flight.
  final bool isSubmitting;

  /// Callback for the back button. `null` hides the button.
  final VoidCallback? onBack;

  /// Callback for the next / finish button.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentStep == totalSteps - 1;

    return Row(
      children: [
        // Back button — only shown when there's a step to go back to.
        if (onBack != null) ...[
          Expanded(
            child: SecondaryButton(
              label: 'Back',
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
        ],

        // Next / Finish primary button.
        Expanded(
          child: PrimaryButton(
            label: isLastStep ? 'Finish' : 'Next',
            isLoading: isSubmitting,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

// ── Step 1 — Name ─────────────────────────────────────────────────────────────

/// Step 1 content: Display name and nickname text fields.
///
/// [formKey] must be provided by the parent to enable validation.
/// [displayNameController] is required; [nicknameController] is optional.
class _Step1Name extends StatelessWidget {
  /// Creates a [_Step1Name].
  const _Step1Name({
    required this.formKey,
    required this.displayNameController,
    required this.nicknameController,
  });

  /// Form key used to validate the display name field.
  final GlobalKey<FormState> formKey;

  /// Controller for the display name field.
  final TextEditingController displayNameController;

  /// Controller for the nickname field.
  final TextEditingController nicknameController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Heading ──────────────────────────────────────────────────
            Text(
              'What should we call you?',
              style: AppTextStyles.h2.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Help us personalise your AI experience.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: AppDimens.spaceXl),

            // ── Display name field ───────────────────────────────────────
            AppTextField(
              hintText: 'Display name (e.g. Alex Johnson)',
              labelText: 'Display name',
              controller: displayNameController,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: AppDimens.spaceMd),

            // ── Nickname field ───────────────────────────────────────────
            AppTextField(
              hintText: 'Nickname (what the AI calls you)',
              labelText: 'Nickname',
              controller: nicknameController,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.tag_rounded),
            ),

            const SizedBox(height: AppDimens.spaceMd),

            Text(
              'The nickname is how your AI coach will address you in conversations.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2 — Birthday ─────────────────────────────────────────────────────────

/// Step 2 content: Birthday selection via the Material date picker.
///
/// Shows a tappable date display tile. Tapping opens [showDatePicker].
class _Step2Birthday extends StatelessWidget {
  /// Creates a [_Step2Birthday].
  const _Step2Birthday({
    required this.birthday,
    required this.onSelectBirthday,
  });

  /// Currently selected birthday, or `null` if not yet chosen.
  final DateTime? birthday;

  /// Callback to open the date picker.
  final VoidCallback onSelectBirthday;

  /// Formats [date] as a human-readable string (e.g. "15 March 2000").
  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ──────────────────────────────────────────────────
          Text(
            'When were you born?',
            style: AppTextStyles.h2.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Used to personalise health recommendations. Optional.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Date picker trigger tile ──────────────────────────────────
          InkWell(
            onTap: onSelectBirthday,
            borderRadius: BorderRadius.circular(AppDimens.radiusInput),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceLg,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: birthday != null
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: birthday != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppDimens.radiusInput),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    color: birthday != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: AppDimens.iconMd,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Text(
                      birthday != null
                          ? _formatDate(birthday!)
                          : 'Select your birthday',
                      style: AppTextStyles.body.copyWith(
                        color: birthday != null
                            ? colorScheme.onSurface
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: AppDimens.iconMd,
                  ),
                ],
              ),
            ),
          ),

          if (birthday == null) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              "You can skip this step — tap Next to continue.",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 3 — Gender ───────────────────────────────────────────────────────────

/// Step 3 content: Gender selection via radio-style option tiles.
///
/// Displays a column of selectable tiles for each gender option.
/// Selection is optional — the user may proceed without choosing.
class _Step3Gender extends StatelessWidget {
  /// Creates a [_Step3Gender].
  const _Step3Gender({
    required this.selectedGender,
    required this.onGenderSelected,
  });

  /// Currently selected gender string, or `null` if not yet chosen.
  final String? selectedGender;

  /// Callback invoked when the user selects a gender option.
  final ValueChanged<String> onGenderSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ──────────────────────────────────────────────────
          Text(
            'How do you identify?',
            style: AppTextStyles.h2.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Helps tailor health insights. Optional.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Gender option tiles ───────────────────────────────────────
          ...List.generate(_genderOptions.length, (index) {
            final option = _genderOptions[index];
            final isSelected = option == selectedGender;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _genderOptions.length - 1
                    ? AppDimens.spaceSm
                    : 0,
              ),
              child: _GenderOptionTile(
                label: option,
                isSelected: isSelected,
                onTap: () => onGenderSelected(option),
              ),
            );
          }),

          if (selectedGender == null) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              "You can skip this — tap Finish to complete setup.",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Gender Option Tile ────────────────────────────────────────────────────────

/// A selectable tile representing a single gender option.
///
/// Renders with a highlighted border and radio-indicator when [isSelected].
class _GenderOptionTile extends StatelessWidget {
  /// Creates a [_GenderOptionTile].
  const _GenderOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// The gender label to display.
  final String label;

  /// Whether this tile is currently selected.
  final bool isSelected;

  /// Callback invoked when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusInput),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
        ),
        child: Row(
          children: [
            // Radio indicator circle.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderLight,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? colorScheme.onSurface
                    : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
