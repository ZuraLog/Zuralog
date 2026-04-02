/// Zuralog — Onboarding Step 5: Notifications.
///
/// Lets the user configure three notification preferences:
///   - Morning briefing: toggle + time picker
///   - Smart activity reminders: toggle
///   - Wellness check-in: toggle
///
/// All three are optional — the defaults are sensible for most users.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 5 — notification preference configuration.
class NotificationsStep extends StatelessWidget {
  const NotificationsStep({
    super.key,
    required this.morningBriefingEnabled,
    required this.morningBriefingTime,
    required this.smartRemindersEnabled,
    required this.wellnessCheckInEnabled,
    required this.onMorningBriefingChanged,
    required this.onMorningTimeChanged,
    required this.onSmartRemindersChanged,
    required this.onWellnessCheckInChanged,
  });

  final bool morningBriefingEnabled;
  final TimeOfDay morningBriefingTime;
  final bool smartRemindersEnabled;
  final bool wellnessCheckInEnabled;

  final ValueChanged<bool> onMorningBriefingChanged;
  final ValueChanged<TimeOfDay> onMorningTimeChanged;
  final ValueChanged<bool> onSmartRemindersChanged;
  final ValueChanged<bool> onWellnessCheckInChanged;

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _pickTime(BuildContext context) async {
    final colors = AppColorsOf(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: morningBriefingTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: colors.primary,
                  onPrimary: colors.textOnSage,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onMorningTimeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ────────────────────────────────────────────────────
          Text(
            'Stay in the loop',
            style: AppTextStyles.displayLarge.copyWith(
              color: colors.primary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Customise how Zuralog keeps you informed. '
            'You can change these any time in Settings.',
            style: AppTextStyles.bodyLarge
                .copyWith(color: colors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Morning Briefing ────────────────────────────────────────────
          _NotificationRow(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColors.categoryMobility,
            title: 'Morning briefing',
            description: 'Daily AI summary of your health trends.',
            isEnabled: morningBriefingEnabled,
            onChanged: onMorningBriefingChanged,
            trailing: morningBriefingEnabled
                ? GestureDetector(
                    onTap: () => _pickTime(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppDimens.touchTargetMin,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceSm,
                          vertical: 4,
                        ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapePill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(morningBriefingTime),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit_rounded,
                            color: colors.primary,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Smart Reminders ─────────────────────────────────────────────
          _NotificationRow(
            icon: Icons.notifications_active_rounded,
            iconColor: AppColors.categoryActivity,
            title: 'Smart reminders',
            description: 'Activity and hydration nudges based on your patterns.',
            isEnabled: smartRemindersEnabled,
            onChanged: onSmartRemindersChanged,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Wellness Check-in ───────────────────────────────────────────
          _NotificationRow(
            icon: Icons.sentiment_satisfied_alt_rounded,
            iconColor: AppColors.categoryWellness,
            title: 'Wellness check-in',
            description: 'A short evening prompt to log mood and energy.',
            isEnabled: wellnessCheckInEnabled,
            onChanged: onWellnessCheckInChanged,
          ),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Notification Row ──────────────────────────────────────────────────────────

/// A clean ListTile-style notification preference row with an animated
/// enabled/disabled state. Uses border-left accent color tint when active.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.onChanged,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isEnabled
            ? iconColor.withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          // Text content.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  trailing!,
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          // Brand toggle.
          ZToggle(
            value: isEnabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
