library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/nutrition/domain/tdee_calculator.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_macro_review_screen.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _StepId { height, weight, birthday, sex, goal, pace, activity }

enum WeightGoalChoice { lose, maintain, gain }

// ── NutritionGoalsWizard ──────────────────────────────────────────────────────

class NutritionGoalsWizard extends ConsumerStatefulWidget {
  const NutritionGoalsWizard({super.key});

  @override
  ConsumerState<NutritionGoalsWizard> createState() =>
      _NutritionGoalsWizardState();
}

class _NutritionGoalsWizardState extends ConsumerState<NutritionGoalsWizard> {
  late List<_StepId> _steps;
  int _currentIndex = 0;

  // ── Collected answers ─────────────────────────────────────────────────────
  double? _heightCm;
  double? _weightKg;
  DateTime? _birthday;
  String? _gender;
  WeightGoalChoice? _goalChoice;
  bool? _isPaceAggressive;
  bool _isSavingStats = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _heightCm = profile?.heightCm;
    _weightKg = profile?.weightKg;
    _birthday = profile?.birthday;
    _gender = profile?.gender;

    final missing = <_StepId>[];
    if (_heightCm == null) missing.add(_StepId.height);
    if (_weightKg == null) missing.add(_StepId.weight);
    if (_birthday == null) missing.add(_StepId.birthday);
    if (_gender == null) missing.add(_StepId.sex);

    _steps = [
      ...missing,
      _StepId.goal,
      _StepId.pace,
      _StepId.activity,
    ];
  }

  _StepId get _currentStep => _steps[_currentIndex];

  int get _totalSteps => _steps.length;

  void _next() => setState(() => _currentIndex++);

  void _back() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      context.pop();
    }
  }

  Future<void> _saveStatsToProfile() async {
    setState(() => _isSavingStats = true);
    try {
      await ref.read(userProfileProvider.notifier).update(
            heightCm: _heightCm,
            weightKg: _weightKg,
            birthday: _birthday,
            gender: _gender,
          );
    } catch (_) {
      // Non-fatal — stats are held in local state, wizard continues.
    } finally {
      if (mounted) setState(() => _isSavingStats = false);
    }
  }

  void _onGoalStepContinue(WeightGoalChoice choice) {
    setState(() => _goalChoice = choice);
    if (choice == WeightGoalChoice.maintain) {
      _steps = _steps.where((s) => s != _StepId.pace).toList();
    } else {
      if (!_steps.contains(_StepId.pace)) {
        final goalIdx = _steps.indexOf(_StepId.goal);
        _steps.insert(goalIdx + 1, _StepId.pace);
      }
    }
    _next();
  }

  Future<void> _onActivityContinue(ActivityLevel level) async {
    await _saveStatsToProfile();

    if (!mounted) return;

    final weightGoal = switch (_goalChoice!) {
      WeightGoalChoice.lose =>
        _isPaceAggressive == true ? WeightGoal.loseFast : WeightGoal.loseHalf,
      WeightGoalChoice.maintain => WeightGoal.maintain,
      WeightGoalChoice.gain =>
        _isPaceAggressive == true ? WeightGoal.gainFast : WeightGoal.gainHalf,
    };

    final age = _birthday != null
        ? DateTime.now().year - _birthday!.year
        : 30;
    final isMale = _gender?.toLowerCase() == 'male';

    final calories = TdeeCalculator.calculate(
      weightKg: _weightKg ?? 70,
      heightCm: _heightCm ?? 170,
      ageYears: age,
      isMale: isMale,
      activityLevel: level,
      weightGoal: weightGoal,
    );

    final ranges = NutritionMacroReviewScreen.recommendedRanges(_goalChoice!);
    final proteinG = ((calories * ranges.proteinMid) / 4).round();
    final carbsG = ((calories * ranges.carbsMid) / 4).round();
    final fatG = ((calories * ranges.fatMid) / 9).round();

    context.push(
      NutritionMacroReviewScreen.routePath,
      extra: NutritionMacroReviewArgs(
        calorieBudget: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        goalChoice: _goalChoice!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textPrimary,
          onPressed: _back,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: colors.textSecondary,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgressBar(
            current: _currentIndex,
            total: _totalSteps,
            colors: colors,
          ),
          Expanded(child: _buildStep(colors)),
        ],
      ),
    );
  }

  Widget _buildStep(AppColorsOf colors) {
    switch (_currentStep) {
      case _StepId.height:
        return _HeightStep(
          initialCm: _heightCm,
          onContinue: (cm) {
            setState(() => _heightCm = cm);
            _next();
          },
          colors: colors,
        );
      case _StepId.weight:
        return _WeightStep(
          initialKg: _weightKg,
          onContinue: (kg) {
            setState(() => _weightKg = kg);
            _next();
          },
          colors: colors,
        );
      case _StepId.birthday:
        return _BirthdayStep(
          initial: _birthday,
          onContinue: (date) {
            setState(() => _birthday = date);
            _next();
          },
          colors: colors,
        );
      case _StepId.sex:
        return _SexStep(
          initial: _gender,
          onContinue: (gender) {
            setState(() => _gender = gender);
            _next();
          },
          colors: colors,
        );
      case _StepId.goal:
        return _GoalStep(
          profileWasComplete: _heightCm != null && _weightKg != null && _birthday != null && _gender != null,
          heightCm: _heightCm,
          weightKg: _weightKg,
          birthday: _birthday,
          gender: _gender,
          onContinue: _onGoalStepContinue,
          onEditStats: () => setState(() => _currentIndex = 0),
          colors: colors,
        );
      case _StepId.pace:
        return _PaceStep(
          goalChoice: _goalChoice!,
          onContinue: (isAggressive) {
            setState(() => _isPaceAggressive = isAggressive);
            _next();
          },
          colors: colors,
        );
      case _StepId.activity:
        return _ActivityStep(
          isSaving: _isSavingStats,
          onContinue: _onActivityContinue,
          colors: colors,
        );
    }
  }
}

// ── _ProgressBar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= current ? colors.primary : colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: AppDimens.spaceXs),
          ],
        ],
      ),
    );
  }
}

// ── _WizardPage ───────────────────────────────────────────────────────────────

class _WizardPage extends StatelessWidget {
  const _WizardPage({
    required this.question,
    required this.subtitle,
    required this.content,
    required this.colors,
  });

  final String question;
  final String subtitle;
  final Widget content;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          content,
        ],
      ),
    );
  }
}

// ── _HeightStep ───────────────────────────────────────────────────────────────

class _HeightStep extends ConsumerStatefulWidget {
  const _HeightStep({
    required this.initialCm,
    required this.onContinue,
    required this.colors,
  });

  final double? initialCm;
  final ValueChanged<double> onContinue;
  final AppColorsOf colors;

  @override
  ConsumerState<_HeightStep> createState() => _HeightStepState();
}

class _HeightStepState extends ConsumerState<_HeightStep> {
  late TextEditingController _cmCtrl;
  late TextEditingController _ftCtrl;
  late TextEditingController _inCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.initialCm;
    final isMetric = ref.read(unitsSystemProvider) == UnitsSystem.metric;
    if (isMetric) {
      _cmCtrl = TextEditingController(text: h != null ? h.toStringAsFixed(0) : '');
      _ftCtrl = TextEditingController();
      _inCtrl = TextEditingController();
    } else {
      _cmCtrl = TextEditingController();
      if (h != null) {
        final totalIn = h / 2.54;
        _ftCtrl = TextEditingController(text: (totalIn / 12).floor().toString());
        _inCtrl = TextEditingController(text: (totalIn % 12).round().toString());
      } else {
        _ftCtrl = TextEditingController();
        _inCtrl = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _cmCtrl.dispose();
    _ftCtrl.dispose();
    _inCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isMetric = ref.read(unitsSystemProvider) == UnitsSystem.metric;
    double? cm;
    if (isMetric) {
      final raw = double.tryParse(_cmCtrl.text.trim());
      if (raw == null || raw < 30 || raw > 300) {
        setState(() => _error = 'Enter a height between 30 and 300 cm.');
        return;
      }
      cm = raw;
    } else {
      final ft = double.tryParse(_ftCtrl.text.trim());
      final inches = double.tryParse(_inCtrl.text.trim()) ?? 0;
      if (ft == null) {
        setState(() => _error = 'Enter your height in feet and inches.');
        return;
      }
      cm = ft * 30.48 + inches * 2.54;
      if (cm < 30 || cm > 300) {
        setState(() => _error = 'Enter a valid height.');
        return;
      }
    }
    widget.onContinue(cm);
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = ref.watch(unitsSystemProvider) == UnitsSystem.metric;
    return _WizardPage(
      question: "What's your height?",
      subtitle: 'Used to calculate your daily calorie target. This saves to your Health Profile in Settings.',
      colors: widget.colors,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMetric)
            ZLabeledNumberField(
              label: 'Height',
              controller: _cmCtrl,
              unit: 'cm',
              allowDecimal: false,
              textInputAction: TextInputAction.done,
            )
          else
            Row(
              children: [
                Expanded(
                  child: ZLabeledNumberField(
                    label: 'Feet',
                    controller: _ftCtrl,
                    unit: 'ft',
                    allowDecimal: false,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: ZLabeledNumberField(
                    label: 'Inches',
                    controller: _inCtrl,
                    unit: 'in',
                    allowDecimal: false,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError),
            ),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(label: 'Continue', onPressed: _submit),
        ],
      ),
    );
  }
}

// ── _WeightStep ───────────────────────────────────────────────────────────────

class _WeightStep extends ConsumerStatefulWidget {
  const _WeightStep({
    required this.initialKg,
    required this.onContinue,
    required this.colors,
  });

  final double? initialKg;
  final ValueChanged<double> onContinue;
  final AppColorsOf colors;

  @override
  ConsumerState<_WeightStep> createState() => _WeightStepState();
}

class _WeightStepState extends ConsumerState<_WeightStep> {
  late TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final w = widget.initialKg;
    final isMetric = ref.read(unitsSystemProvider) == UnitsSystem.metric;
    _ctrl = TextEditingController(
      text: w != null
          ? isMetric
              ? w.toStringAsFixed(1)
              : (w / 0.453592).round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isMetric = ref.read(unitsSystemProvider) == UnitsSystem.metric;
    final raw = double.tryParse(_ctrl.text.trim());
    double? kg;
    if (isMetric) {
      if (raw == null || raw < 1 || raw > 500) {
        setState(() => _error = 'Enter a weight between 1 and 500 kg.');
        return;
      }
      kg = raw;
    } else {
      if (raw == null || raw < 2 || raw > 1100) {
        setState(() => _error = 'Enter a weight between 2 and 1,100 lbs.');
        return;
      }
      kg = raw * 0.453592;
    }
    widget.onContinue(kg);
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = ref.watch(unitsSystemProvider) == UnitsSystem.metric;
    return _WizardPage(
      question: "What's your weight?",
      subtitle: 'Used to calculate your daily calorie target. This saves to your Health Profile in Settings.',
      colors: widget.colors,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabeledNumberField(
            label: 'Weight',
            controller: _ctrl,
            unit: isMetric ? 'kg' : 'lbs',
            allowDecimal: true,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError),
            ),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(label: 'Continue', onPressed: _submit),
        ],
      ),
    );
  }
}

// ── _BirthdayStep ─────────────────────────────────────────────────────────────

class _BirthdayStep extends StatefulWidget {
  const _BirthdayStep({
    required this.initial,
    required this.onContinue,
    required this.colors,
  });

  final DateTime? initial;
  final ValueChanged<DateTime> onContinue;
  final AppColorsOf colors;

  @override
  State<_BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<_BirthdayStep> {
  late DateTime _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial ?? DateTime(1990, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return _WizardPage(
      question: 'When were you born?',
      subtitle: 'Your age affects your metabolic rate. This saves to your Health Profile in Settings.',
      colors: widget.colors,
      content: Column(
        children: [
          SizedBox(
            height: 200,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _picked,
              minimumDate: DateTime(1900),
              maximumDate: DateTime.now(),
              onDateTimeChanged: (d) => setState(() => _picked = d),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: 'Continue',
            onPressed: () => widget.onContinue(_picked),
          ),
        ],
      ),
    );
  }
}

// ── _SexStep ──────────────────────────────────────────────────────────────────

class _SexStep extends StatefulWidget {
  const _SexStep({
    required this.initial,
    required this.onContinue,
    required this.colors,
  });

  final String? initial;
  final ValueChanged<String> onContinue;
  final AppColorsOf colors;

  @override
  State<_SexStep> createState() => _SexStepState();
}

class _SexStepState extends State<_SexStep> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return _WizardPage(
      question: "What's your biological sex?",
      subtitle: 'The Mifflin-St Jeor formula uses biological sex to estimate your resting metabolic rate.',
      colors: widget.colors,
      content: Column(
        children: [
          for (final option in ['Male', 'Female']) ...[
            ZSelectableTile(
              isSelected: _selected == option,
              onTap: () => setState(() => _selected = option),
              showCheckIndicator: true,
              child: Text(
                option,
                style: AppTextStyles.bodyLarge.copyWith(color: widget.colors.textPrimary),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: 'Continue',
            onPressed: _selected != null ? () => widget.onContinue(_selected!) : null,
          ),
        ],
      ),
    );
  }
}

// ── _GoalStep ─────────────────────────────────────────────────────────────────

class _GoalStep extends StatefulWidget {
  const _GoalStep({
    required this.profileWasComplete,
    required this.heightCm,
    required this.weightKg,
    required this.birthday,
    required this.gender,
    required this.onContinue,
    required this.onEditStats,
    required this.colors,
  });

  final bool profileWasComplete;
  final double? heightCm;
  final double? weightKg;
  final DateTime? birthday;
  final String? gender;
  final ValueChanged<WeightGoalChoice> onContinue;
  final VoidCallback onEditStats;
  final AppColorsOf colors;

  @override
  State<_GoalStep> createState() => _GoalStepState();
}

class _GoalStepState extends State<_GoalStep> {
  WeightGoalChoice? _selected;

  String _formatStats() {
    final age = widget.birthday != null
        ? '${DateTime.now().year - widget.birthday!.year} yo'
        : '';
    final height = widget.heightCm != null
        ? '${widget.heightCm!.toStringAsFixed(0)} cm'
        : '';
    final weight = widget.weightKg != null
        ? '${widget.weightKg!.toStringAsFixed(1)} kg'
        : '';
    final sex = widget.gender ?? '';
    return [height, weight, age, sex].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return _WizardPage(
      question: "What's your goal?",
      subtitle: 'This shapes your entire calorie target.',
      colors: colors,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.profileWasComplete) ...[
            Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.shapeMd),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your stats',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatStats(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Changing these updates your Health Profile.',
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onEditStats,
                    child: Text(
                      'Edit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          for (final option in WeightGoalChoice.values) ...[
            ZSelectableTile(
              isSelected: _selected == option,
              onTap: () => setState(() => _selected = option),
              showCheckIndicator: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (option) {
                      WeightGoalChoice.lose => 'Lose weight',
                      WeightGoalChoice.maintain => 'Maintain weight',
                      WeightGoalChoice.gain => 'Gain weight',
                    },
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    switch (option) {
                      WeightGoalChoice.lose => "You'll eat below your burn rate",
                      WeightGoalChoice.maintain => "You'll eat at your burn rate",
                      WeightGoalChoice.gain => "You'll eat above your burn rate",
                    },
                    style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: 'Continue',
            onPressed: _selected != null ? () => widget.onContinue(_selected!) : null,
          ),
        ],
      ),
    );
  }
}

// ── _PaceStep ─────────────────────────────────────────────────────────────────

class _PaceStep extends StatefulWidget {
  const _PaceStep({
    required this.goalChoice,
    required this.onContinue,
    required this.colors,
  });

  final WeightGoalChoice goalChoice;
  final ValueChanged<bool> onContinue;
  final AppColorsOf colors;

  @override
  State<_PaceStep> createState() => _PaceStepState();
}

class _PaceStepState extends State<_PaceStep> {
  bool? _isAggressive;

  @override
  Widget build(BuildContext context) {
    final isLosing = widget.goalChoice == WeightGoalChoice.lose;
    return _WizardPage(
      question: 'How fast?',
      subtitle: 'Steady is more sustainable and easier to maintain long-term.',
      colors: widget.colors,
      content: Column(
        children: [
          ZSelectableTile(
            isSelected: _isAggressive == false,
            onTap: () => setState(() => _isAggressive = false),
            showCheckIndicator: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Steady',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: widget.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLosing ? '−250 kcal/day · ~0.25 kg/week' : '+250 kcal/day · ~0.25 kg/week',
                  style: AppTextStyles.bodySmall.copyWith(color: widget.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          ZSelectableTile(
            isSelected: _isAggressive == true,
            onTap: () => setState(() => _isAggressive = true),
            showCheckIndicator: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aggressive',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: widget.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLosing ? '−500 kcal/day · ~0.5 kg/week' : '+500 kcal/day · ~0.5 kg/week',
                  style: AppTextStyles.bodySmall.copyWith(color: widget.colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: 'Continue',
            onPressed: _isAggressive != null ? () => widget.onContinue(_isAggressive!) : null,
          ),
        ],
      ),
    );
  }
}

// ── _ActivityStep ─────────────────────────────────────────────────────────────

class _ActivityStep extends StatefulWidget {
  const _ActivityStep({
    required this.isSaving,
    required this.onContinue,
    required this.colors,
  });

  final bool isSaving;
  final ValueChanged<ActivityLevel> onContinue;
  final AppColorsOf colors;

  @override
  State<_ActivityStep> createState() => _ActivityStepState();
}

class _ActivityStepState extends State<_ActivityStep> {
  ActivityLevel? _selected;

  static const _labels = {
    ActivityLevel.sedentary: ('Sedentary', 'Little or no exercise'),
    ActivityLevel.lightlyActive: ('Lightly active', '1–3 days/week'),
    ActivityLevel.moderatelyActive: ('Moderately active', '3–5 days/week'),
    ActivityLevel.veryActive: ('Very active', '6–7 days/week'),
    ActivityLevel.extraActive: ('Extra active', 'Physical job or twice-a-day training'),
  };

  @override
  Widget build(BuildContext context) {
    return _WizardPage(
      question: 'How active are you?',
      subtitle: 'Pick the level that best describes a typical week for you.',
      colors: widget.colors,
      content: Column(
        children: [
          for (final level in ActivityLevel.values) ...[
            ZSelectableTile(
              isSelected: _selected == level,
              onTap: () => setState(() => _selected = level),
              showCheckIndicator: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labels[level]!.$1,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: widget.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labels[level]!.$2,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: widget.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          ZButton(
            label: widget.isSaving ? 'Saving…' : 'Calculate my targets',
            onPressed: (_selected != null && !widget.isSaving)
                ? () => widget.onContinue(_selected!)
                : null,
          ),
        ],
      ),
    );
  }
}
