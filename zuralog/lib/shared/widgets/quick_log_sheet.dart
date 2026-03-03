/// Zuralog — QuickLogSheet widget.
///
/// Modal bottom sheet for rapid manual health data entry. Launched from the
/// FAB on the Today Feed and from the Coach tab Quick Actions.
///
/// ## Layout
/// ```
/// ┌─────────────────────────────────────┐
/// │  Drag handle                         │
/// │  "Quick Log"  (H2)                   │
/// ├──────────────────────────────────────┤
/// │  Mood     ────●────────  7/10        │
/// │  Energy   ──────●──────  6/10        │
/// │  Stress   ────────●────  5/10        │
/// ├──────────────────────────────────────┤
/// │  Water: [−]  [3]  [+]   glasses      │
/// ├──────────────────────────────────────┤
/// │  Notes (optional)  [text field]      │
/// │  Symptoms          [tag chips row]   │
/// ├──────────────────────────────────────┤
/// │  [      Submit      ]  (FilledButton) │
/// └─────────────────────────────────────┘
/// ```
///
/// ## Usage
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => QuickLogSheet(
///     onSubmit: (data) { /* send to API */ },
///   ),
/// );
/// ```
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── QuickLogData ──────────────────────────────────────────────────────────────

/// Data payload submitted by [QuickLogSheet].
class QuickLogData {
  /// Creates a [QuickLogData].
  const QuickLogData({
    required this.mood,
    required this.energy,
    required this.stress,
    required this.waterGlasses,
    required this.notes,
    required this.symptoms,
  });

  final double mood;
  final double energy;
  final double stress;
  final int waterGlasses;
  final String notes;
  final List<String> symptoms;
}

// ── QuickLogSheet ─────────────────────────────────────────────────────────────

/// Modal bottom sheet for rapid manual health data entry.
class QuickLogSheet extends StatefulWidget {
  /// Creates a [QuickLogSheet].
  const QuickLogSheet({super.key, required this.onSubmit, this.isLoading = false});

  /// Called with the completed [QuickLogData] when the user taps Submit.
  final ValueChanged<QuickLogData> onSubmit;

  /// When `true` the submit button shows a loading indicator.
  final bool isLoading;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  // ── State fields ───────────────────────────────────────────────────────────
  double _mood = 7;
  double _energy = 6;
  double _stress = 4;
  int _water = 0;
  final _notesCtrl = TextEditingController();
  final Set<String> _selectedSymptoms = {};

  static const List<String> _symptomOptions = [
    'Headache',
    'Fatigue',
    'Nausea',
    'Sore muscles',
    'Bloated',
    'Brain fog',
    'Low energy',
    'Restless',
    'Anxious',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSubmit(
      QuickLogData(
        mood: _mood,
        energy: _energy,
        stress: _stress,
        waterGlasses: _water,
        notes: _notesCtrl.text.trim(),
        symptoms: _selectedSymptoms.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Text(
                'Quick Log',
                style: AppTextStyles.h2.copyWith(color: textPrimary),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Content — scrollable so it works on small screens
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Sliders ─────────────────────────────────────────────
                    _SliderRow(
                      label: 'Mood',
                      value: _mood,
                      color: AppColors.categoryWellness,
                      textColor: textPrimary,
                      secondaryColor: textSecondary,
                      onChanged: (v) => setState(() => _mood = v),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    _SliderRow(
                      label: 'Energy',
                      value: _energy,
                      color: AppColors.categoryActivity,
                      textColor: textPrimary,
                      secondaryColor: textSecondary,
                      onChanged: (v) => setState(() => _energy = v),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    _SliderRow(
                      label: 'Stress',
                      value: _stress,
                      color: AppColors.categoryHeart,
                      textColor: textPrimary,
                      secondaryColor: textSecondary,
                      onChanged: (v) => setState(() => _stress = v),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),

                    // ── Water counter ───────────────────────────────────────
                    _WaterCounter(
                      count: _water,
                      textColor: textPrimary,
                      secondaryColor: textSecondary,
                      onDecrement: () {
                        if (_water > 0) setState(() => _water--);
                      },
                      onIncrement: () => setState(() => _water++),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),

                    // ── Notes field ─────────────────────────────────────────
                    TextField(
                      controller: _notesCtrl,
                      style: AppTextStyles.body.copyWith(color: textPrimary),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Notes (optional)',
                        hintStyle: AppTextStyles.body
                            .copyWith(color: textSecondary),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),

                    // ── Symptoms ────────────────────────────────────────────
                    Text(
                      'Symptoms',
                      style:
                          AppTextStyles.caption.copyWith(color: textSecondary),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final symptom in _symptomOptions)
                          FilterChip(
                            label: Text(
                              symptom,
                              style: AppTextStyles.caption,
                            ),
                            selected: _selectedSymptoms.contains(symptom),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSymptoms.add(symptom);
                                } else {
                                  _selectedSymptoms.remove(symptom);
                                }
                              });
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primary,
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : AppColors.surfaceLight,
                            side: BorderSide(
                              color: _selectedSymptoms.contains(symptom)
                                  ? AppColors.primary
                                  : AppColors.borderDark.withValues(alpha: 0.3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                ),
              ),
            ),

            // ── Submit bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: FilledButton(
                onPressed: widget.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryButtonText,
                        ),
                      )
                    : Text('Submit', style: AppTextStyles.h3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SliderRow ─────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final Color textColor;
  final Color secondaryColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: secondaryColor),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${value.round()}/10',
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── _WaterCounter ─────────────────────────────────────────────────────────────

class _WaterCounter extends StatelessWidget {
  const _WaterCounter({
    required this.count,
    required this.textColor,
    required this.secondaryColor,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int count;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Water',
          style: AppTextStyles.caption.copyWith(color: secondaryColor),
        ),
        const Spacer(),
        _CounterButton(
          icon: Icons.remove_rounded,
          onTap: onDecrement,
          enabled: count > 0,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Text(
            '$count',
            style: AppTextStyles.h2.copyWith(color: textColor),
          ),
        ),
        _CounterButton(
          icon: Icons.add_rounded,
          onTap: onIncrement,
          enabled: true,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          'glasses',
          style: AppTextStyles.caption.copyWith(color: secondaryColor),
        ),
      ],
    );
  }
}

// ── _CounterButton ────────────────────────────────────────────────────────────

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}
