/// Zuralog — Catch-up Sheet.
///
/// A single bottom sheet that covers the full catch-up flow:
/// [intro →] tone → diet → limitations → training → sleep → frustration → save.
///
/// Call [showCatchupIntroSheet] for the first-run prompt (includes the intro
/// screen asking the user if they want to take the quiz).
/// Call [showCatchupFlowSheet] from Settings to jump straight to question 1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows the full catch-up sheet including the intro screen.
Future<void> showCatchupIntroSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CatchupSheet(),
  );
}

/// Shows the catch-up questions sheet without the intro (e.g. from Settings).
Future<void> showCatchupFlowSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CatchupSheet(skipIntro: true),
  );
}

// ── Step enum ─────────────────────────────────────────────────────────────────

enum _Step { intro, tone, diet, limitations, training, sleep, frustration }

// ── _CatchupSheet ─────────────────────────────────────────────────────────────

class _CatchupSheet extends ConsumerStatefulWidget {
  const _CatchupSheet({this.skipIntro = false});

  final bool skipIntro;

  @override
  ConsumerState<_CatchupSheet> createState() => _CatchupSheetState();
}

class _CatchupSheetState extends ConsumerState<_CatchupSheet> {
  static const _questionSteps = [
    _Step.tone,
    _Step.diet,
    _Step.limitations,
    _Step.training,
    _Step.sleep,
    _Step.frustration,
  ];

  late _Step _step;

  // Collected answers
  String? _tone;
  List<String> _diet = const [];
  bool _dietAnswered = false;
  final _dietOtherCtrl = TextEditingController();

  List<String> _injuries = const [];
  bool _injuriesAnswered = false;
  final _injuriesOtherCtrl = TextEditingController();

  String? _training;
  String? _sleep;
  final _frustrationCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _step = widget.skipIntro ? _Step.tone : _Step.intro;
  }

  @override
  void dispose() {
    _dietOtherCtrl.dispose();
    _injuriesOtherCtrl.dispose();
    _frustrationCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  bool get _isQuestion => _step != _Step.intro;
  bool get _isLastQuestion => _step == _Step.frustration;
  int get _questionIndex => _questionSteps.indexOf(_step);

  void _advance() {
    if (_step == _Step.intro) {
      setState(() => _step = _Step.tone);
      return;
    }
    if (_isLastQuestion) {
      _save();
      return;
    }
    final i = _questionIndex;
    setState(() => _step = _questionSteps[i + 1]);
  }

  Future<void> _dismiss() async {
    try {
      await ref.read(userProfileProvider.notifier).update(
            profileCatchupStatus: 'dismissed',
          );
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  List<String> _resolveList(List<String> values, TextEditingController ctrl) {
    if (!values.contains('other')) return values;
    final custom = ctrl.text.trim();
    if (custom.isEmpty) return values;
    return [...values.where((v) => v != 'other'), custom];
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userProfileProvider.notifier).update(
            tone: _tone,
            dietaryRestrictions:
                _dietAnswered ? _resolveList(_diet, _dietOtherCtrl) : null,
            injuries: _injuriesAnswered
                ? _resolveList(_injuries, _injuriesOtherCtrl)
                : null,
            fitnessLevel: _training,
            sleepPattern: _sleep,
            healthFrustration: _frustrationCtrl.text.trim().isNotEmpty
                ? _frustrationCtrl.text.trim()
                : null,
            profileCatchupStatus: 'completed',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            margin: const EdgeInsets.all(AppDimens.spaceLg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isQuestion) ...[
                    _ProgressDots(
                      current: _questionIndex,
                      total: _questionSteps.length,
                      colors: colors,
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(colors),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppColorsOf colors) {
    switch (_step) {
      case _Step.intro:
        return _IntroContent(onStart: _advance, onDismiss: _dismiss);

      case _Step.tone:
        return _QuestionStep(
          prompt: 'How should I talk to you?',
          colors: colors,
          onSkip: _advance,
          actionLabel: 'Confirm',
          onAction: _advance,
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'warm', label: 'Warm'),
              ZChipOption(value: 'direct', label: 'Direct'),
              ZChipOption(value: 'minimal', label: 'Minimal'),
              ZChipOption(value: 'thorough', label: 'Thorough'),
            ],
            value: _tone,
            onChanged: (v) => setState(() => _tone = v),
          ),
        );

      case _Step.diet:
        return _QuestionStep(
          prompt: 'Any dietary style I should stick to?',
          colors: colors,
          onSkip: _advance,
          actionLabel: 'Next',
          onAction: _advance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZChipMultiSelect<String>(
                options: const [
                  ZChipOption(value: 'vegetarian', label: 'Vegetarian'),
                  ZChipOption(value: 'vegan', label: 'Vegan'),
                  ZChipOption(value: 'gluten_free', label: 'Gluten-free'),
                  ZChipOption(value: 'keto', label: 'Keto'),
                  ZChipOption(value: 'halal', label: 'Halal'),
                  ZChipOption(value: 'kosher', label: 'Kosher'),
                  ZChipOption(value: 'other', label: 'Other'),
                ],
                values: _diet,
                exclusiveLabel: 'None',
                onChanged: (v) => setState(() {
                  _diet = v;
                  _dietAnswered = true;
                }),
              ),
              if (_diet.contains('other')) ...[
                const SizedBox(height: AppDimens.spaceMd),
                AppTextField(
                  controller: _dietOtherCtrl,
                  hintText: 'e.g. diabetic-friendly, low-FODMAP…',
                  textInputAction: TextInputAction.done,
                ),
              ],
            ],
          ),
        );

      case _Step.limitations:
        return _QuestionStep(
          prompt: 'Anything I should avoid suggesting?',
          subtitle: 'Any injuries or physical limitations?',
          colors: colors,
          onSkip: _advance,
          actionLabel: 'Next',
          onAction: _advance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZChipMultiSelect<String>(
                options: const [
                  ZChipOption(value: 'lower_back', label: 'Lower back'),
                  ZChipOption(value: 'knees', label: 'Knees'),
                  ZChipOption(value: 'shoulders', label: 'Shoulders'),
                  ZChipOption(value: 'wrists', label: 'Wrists'),
                  ZChipOption(value: 'other', label: 'Other'),
                ],
                values: _injuries,
                exclusiveLabel: "I'm good",
                onChanged: (v) => setState(() {
                  _injuries = v;
                  _injuriesAnswered = true;
                }),
              ),
              if (_injuries.contains('other')) ...[
                const SizedBox(height: AppDimens.spaceMd),
                AppTextField(
                  controller: _injuriesOtherCtrl,
                  hintText: 'e.g. hip replacement, herniated disc…',
                  textInputAction: TextInputAction.done,
                ),
              ],
            ],
          ),
        );

      case _Step.training:
        return _QuestionStep(
          prompt: 'Where are you at with training right now?',
          colors: colors,
          onSkip: _advance,
          actionLabel: 'Confirm',
          onAction: _advance,
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'beginner', label: 'New to this'),
              ZChipOption(value: 'active', label: 'Consistently active'),
              ZChipOption(value: 'athletic', label: 'Highly trained'),
            ],
            value: _training,
            onChanged: (v) => setState(() => _training = v),
          ),
        );

      case _Step.sleep:
        return _QuestionStep(
          prompt: "How's your sleep usually?",
          colors: colors,
          onSkip: _advance,
          actionLabel: 'Confirm',
          onAction: _advance,
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'great', label: 'I sleep great'),
              ZChipOption(value: 'hard_to_fall_asleep', label: 'Hard to fall asleep'),
              ZChipOption(value: 'wake_up_a_lot', label: 'Wake up a lot'),
              ZChipOption(value: 'short_hours', label: 'Short hours'),
            ],
            value: _sleep,
            onChanged: (v) => setState(() => _sleep = v),
          ),
        );

      case _Step.frustration:
        return _QuestionStep(
          prompt: "What's the biggest thing in your way?",
          subtitle: 'One sentence is fine.',
          colors: colors,
          onSkip: _saving ? null : _advance,
          actionLabel: _saving ? 'Saving…' : 'Done',
          onAction: _saving ? null : _advance,
          child: ZTextArea(
            controller: _frustrationCtrl,
            placeholder: 'My biggest blocker is…',
            minLines: 3,
            maxLines: 5,
            maxLength: 120,
          ),
        );
    }
  }
}

// ── _IntroContent ─────────────────────────────────────────────────────────────

class _IntroContent extends StatelessWidget {
  const _IntroContent({required this.onStart, required this.onDismiss});

  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Let's get to know you better",
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          "I just learned a few new ways to be actually useful to you. "
          "Got 30 seconds for five quick questions?",
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ZPatternPillButton(
          icon: Icons.arrow_forward_rounded,
          label: "Let's do it",
          onPressed: onStart,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SecondaryButton(label: 'Maybe later', onPressed: onDismiss),
      ],
    );
  }
}

// ── _QuestionStep ─────────────────────────────────────────────────────────────

class _QuestionStep extends StatelessWidget {
  const _QuestionStep({
    required this.prompt,
    required this.child,
    required this.colors,
    required this.onSkip,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
  });

  final String prompt;
  final String? subtitle;
  final Widget child;
  final AppColorsOf colors;
  final VoidCallback? onSkip;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: AppTextStyles.titleLarge.copyWith(color: colors.textPrimary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceMd),
        child,
        const SizedBox(height: AppDimens.spaceLg),
        ZButton(label: actionLabel, onPressed: onAction),
        const SizedBox(height: AppDimens.spaceSm),
        SecondaryButton(label: 'Skip', onPressed: onSkip),
      ],
    );
  }
}

// ── _ProgressDots ─────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? colors.primary
                : colors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
