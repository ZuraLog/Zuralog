/// Zuralog — Catch-up Flow Screen.
///
/// A compact wizard shown to existing users who predate the extended
/// profile questions. Walks them through the five missing questions one
/// at a time and PATCHes the result on the final submit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Ordered list of catch-up steps. Kept local to this file — the
/// onboarding controller's ChatStep serves a different flow.
enum _CatchupStep {
  tone,
  diet,
  limitations,
  training,
  sleep,
  frustration,
  save,
}

class CatchupFlowScreen extends ConsumerStatefulWidget {
  const CatchupFlowScreen({super.key});

  @override
  ConsumerState<CatchupFlowScreen> createState() => _CatchupFlowScreenState();
}

class _CatchupFlowScreenState extends ConsumerState<CatchupFlowScreen> {
  _CatchupStep _step = _CatchupStep.tone;

  String? _tone;
  List<String> _diet = const [];
  bool _dietAnswered = false;
  List<String> _injuries = const [];
  bool _injuriesAnswered = false;
  String? _training;
  String? _sleep;
  String? _frustration;

  bool _saving = false;

  void _next() {
    setState(() {
      final values = _CatchupStep.values;
      final i = values.indexOf(_step);
      _step = values[i + 1];
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userProfileProvider.notifier).update(
            tone: _tone,
            dietaryRestrictions: _dietAnswered ? _diet : null,
            injuries: _injuriesAnswered ? _injuries : null,
            fitnessLevel: _training,
            sleepPattern: _sleep,
            healthFrustration: (_frustration ?? '').trim().isNotEmpty
                ? _frustration
                : null,
            profileCatchupStatus: 'completed',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // Keep the user on the screen so they can retry.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('A few quick ones'),
        actions: [
          TextButton(
            onPressed: _step == _CatchupStep.save ? null : _next,
            child: Text(
              'Skip',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: _buildStep(context),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _CatchupStep.tone:
        return _QuestionLayout(
          prompt: 'How should I talk to you?',
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'warm', label: 'Warm'),
              ZChipOption(value: 'direct', label: 'Direct'),
              ZChipOption(value: 'minimal', label: 'Minimal'),
              ZChipOption(value: 'thorough', label: 'Thorough'),
            ],
            value: _tone,
            onChanged: (v) {
              setState(() => _tone = v);
              _next();
            },
          ),
        );
      case _CatchupStep.diet:
        return _QuestionLayout(
          prompt: 'Any dietary style I should stick to?',
          actionLabel: 'Next',
          onAction: _next,
          child: ZChipMultiSelect<String>(
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
            onChanged: (v) {
              setState(() {
                _diet = v;
                _dietAnswered = true;
              });
            },
          ),
        );
      case _CatchupStep.limitations:
        return _QuestionLayout(
          prompt: "Anything I should avoid suggesting because of an injury?",
          actionLabel: 'Next',
          onAction: _next,
          child: ZChipMultiSelect<String>(
            options: const [
              ZChipOption(value: 'lower_back', label: 'Lower back'),
              ZChipOption(value: 'knees', label: 'Knees'),
              ZChipOption(value: 'shoulders', label: 'Shoulders'),
              ZChipOption(value: 'wrists', label: 'Wrists'),
              ZChipOption(value: 'other', label: 'Other'),
            ],
            values: _injuries,
            exclusiveLabel: "I'm good",
            onChanged: (v) {
              setState(() {
                _injuries = v;
                _injuriesAnswered = true;
              });
            },
          ),
        );
      case _CatchupStep.training:
        return _QuestionLayout(
          prompt: 'Where are you at with training right now?',
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'beginner', label: 'New to this'),
              ZChipOption(value: 'active', label: 'Consistently active'),
              ZChipOption(value: 'athletic', label: 'Highly trained'),
            ],
            value: _training,
            onChanged: (v) {
              setState(() => _training = v);
              _next();
            },
          ),
        );
      case _CatchupStep.sleep:
        return _QuestionLayout(
          prompt: "How's your sleep usually?",
          child: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'great', label: 'I sleep great'),
              ZChipOption(value: 'hard_to_fall_asleep', label: 'Hard to fall asleep'),
              ZChipOption(value: 'wake_up_a_lot', label: 'Wake up a lot'),
              ZChipOption(value: 'short_hours', label: 'Short hours'),
            ],
            value: _sleep,
            onChanged: (v) {
              setState(() => _sleep = v);
              _next();
            },
          ),
        );
      case _CatchupStep.frustration:
        return _QuestionLayout(
          prompt: "What's the biggest thing in your way?",
          subtitle: 'One sentence is fine, or tap skip.',
          child: ZChatTextField(
            maxLength: 120,
            placeholder: 'Biggest blocker',
            onSubmit: (text) {
              setState(() => _frustration = text);
              _next();
            },
          ),
        );
      case _CatchupStep.save:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "All done.",
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              PrimaryButton(
                label: _saving ? 'Saving…' : 'Save',
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        );
    }
  }
}

class _QuestionLayout extends StatelessWidget {
  const _QuestionLayout({
    required this.prompt,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String prompt;
  final String? subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
          ),
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
        const SizedBox(height: AppDimens.spaceLg),
        child,
        if (actionLabel != null) ...[
          const Spacer(),
          PrimaryButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );
  }
}
