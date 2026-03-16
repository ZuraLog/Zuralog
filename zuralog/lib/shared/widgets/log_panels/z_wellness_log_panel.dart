/// Zuralog — Wellness Check-in Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Wellness tile.
/// Allows a quick check-in with optional mood, energy, and stress sliders
/// plus an optional notes field.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

/// Data captured in a single wellness check-in.
///
/// All slider fields are nullable — only touched sliders are included.
class WellnessLogData {
  const WellnessLogData({
    this.mood,
    this.energy,
    this.stress,
    this.notes,
  });

  final double? mood;
  final double? energy;
  final double? stress;
  final String? notes;
}

// ── ZWellnessLogPanel ──────────────────────────────────────────────────────────

/// Inline log panel for a wellness check-in.
///
/// Three sliders (Mood, Energy, Stress) start at the midpoint but are
/// considered "untouched" until the user moves them. At least one slider
/// must be touched to enable the Save button.
///
/// An optional notes [TextField] is shown below the sliders with a 500-char
/// limit.
///
/// The [onSave] callback receives a [WellnessLogData] with nullable fields
/// for each untouched slider.
class ZWellnessLogPanel extends ConsumerStatefulWidget {
  const ZWellnessLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Save Check-in". Receives the check-in data.
  final Future<void> Function(WellnessLogData data) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZWellnessLogPanel> createState() => _ZWellnessLogPanelState();
}

class _ZWellnessLogPanelState extends ConsumerState<ZWellnessLogPanel> {
  // Slider values — start at midpoint 5.5.
  double _moodValue = 5.5;
  double _energyValue = 5.5;
  double _stressValue = 5.5;

  // Track whether each slider has been moved by the user.
  bool _moodTouched = false;
  bool _energyTouched = false;
  bool _stressTouched = false;

  final TextEditingController _notesController = TextEditingController();

  bool get _canSave => _moodTouched || _energyTouched || _stressTouched;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;
    final data = WellnessLogData(
      mood: _moodTouched ? _moodValue : null,
      energy: _energyTouched ? _energyValue : null,
      stress: _stressTouched ? _stressValue : null,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
    await widget.onSave(data);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Subtitle ──────────────────────────────────────────────────────
          Text(
            'All optional — fill in what feels right',
            style:
                AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Mood slider ───────────────────────────────────────────────────
          _SliderRow(
            emoji: '😊',
            label: 'Mood',
            value: _moodValue,
            isTouched: _moodTouched,
            activeColor: AppColors.categoryWellness,
            onChanged: (v) => setState(() {
              _moodValue = v;
              _moodTouched = true;
            }),
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Energy slider ─────────────────────────────────────────────────
          _SliderRow(
            emoji: '⚡',
            label: 'Energy',
            value: _energyValue,
            isTouched: _energyTouched,
            activeColor: AppColors.healthScoreAmber,
            onChanged: (v) => setState(() {
              _energyValue = v;
              _energyTouched = true;
            }),
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Stress slider ─────────────────────────────────────────────────
          _SliderRow(
            emoji: '😤',
            label: 'Stress',
            value: _stressValue,
            isTouched: _stressTouched,
            activeColor: AppColors.categoryHeart,
            onChanged: (v) => setState(() {
              _stressValue = v;
              _stressTouched = true;
            }),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Notes field ───────────────────────────────────────────────────
          TextField(
            controller: _notesController,
            maxLength: 500,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: "How's your day going?",
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
              counterStyle: AppTextStyles.labelSmall
                  .copyWith(color: colors.textTertiary),
            ),
            cursorColor: AppColors.primary,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Save button ───────────────────────────────────────────────────
          FilledButton(
            onPressed: _canSave ? _handleSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusButton),
              ),
              minimumSize: const Size.fromHeight(AppDimens.touchTargetMin),
            ),
            child: Text(
              'Save Check-in',
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _SliderRow ─────────────────────────────────────────────────────────────────

/// A labelled slider row with an emoji, label, and value display.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.isTouched,
    required this.activeColor,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final double value;
  final bool isTouched;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final sliderColor = isTouched ? activeColor : colors.textTertiary;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppDimens.spaceSm),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: AppTextStyles.labelMedium
                .copyWith(color: colors.textPrimary),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: sliderColor,
              thumbColor: sliderColor,
              inactiveTrackColor: sliderColor.withAlpha(51),
              overlayColor: sliderColor.withAlpha(26),
            ),
            child: Slider(
              value: value,
              min: 1.0,
              max: 10.0,
              divisions: 18,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: AppTextStyles.labelSmall.copyWith(
              color: isTouched ? colors.textPrimary : colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
