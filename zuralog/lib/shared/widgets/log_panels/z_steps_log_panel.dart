/// Zuralog — Steps Inline Log Panel.
///
/// Displayed inside the ZLogGridSheet when the user taps the Steps tile.
/// Allows manual entry of a step count. A placeholder sync banner is shown
/// for future Health Connect / Apple Health integration.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── ZStepsLogPanel ─────────────────────────────────────────────────────────────

/// Inline log panel for manual step count entry.
///
/// Shows a numeric [TextField] for the step count, a placeholder sync banner
/// for future device integration, and a "Goal: —" stub row.
///
/// The Save button is enabled only when `_steps > 0`.
///
/// The [onSave] callback receives the step count as an [int].
class ZStepsLogPanel extends ConsumerStatefulWidget {
  const ZStepsLogPanel({
    super.key,
    required this.onSave,
    required this.onBack,
  });

  /// Called when the user taps "Save Steps". Receives the step count.
  final void Function(int steps) onSave;

  /// Called by the parent when the user taps the back button in the sheet header.
  final VoidCallback onBack;

  @override
  ConsumerState<ZStepsLogPanel> createState() => _ZStepsLogPanelState();
}

class _ZStepsLogPanelState extends ConsumerState<ZStepsLogPanel> {
  int _steps = 0;
  final TextEditingController _controller = TextEditingController();

  bool get _canSave => _steps > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final parsed = int.tryParse(value) ?? 0;
    setState(() => _steps = parsed);
  }

  void _handleSave() {
    // TODO(Part 4): Call repository. Endpoint: POST /api/v1/logs/steps
    // Body: { steps: int, source: 'manual', logged_at: ISO8601 }
    widget.onSave(_steps);
    ref.invalidate(todayLogSummaryProvider);
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
          // ── Step count input ──────────────────────────────────────────────
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Enter step count',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: colors.textTertiary),
            ),
            onChanged: _onChanged,
            cursorColor: AppColors.primary,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Sync banner (MVP placeholder) ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Text(
              'Synced step data will appear here once connected.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Goal stub ─────────────────────────────────────────────────────
          Text(
            'Goal: —',
            style:
                AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
          ),

          const SizedBox(height: AppDimens.spaceLg),

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
              'Save Steps',
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
