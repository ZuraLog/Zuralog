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
    final picked = await showTimePicker(
      context: context,
      initialTime: morningBriefingTime,
      builder: (context, child) {
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
    if (picked != null) onMorningTimeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            style: AppTextStyles.h1.copyWith(
              color: colorScheme.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Customise how Zuralog keeps you informed. '
            'You can change these any time in Settings.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Morning Briefing ────────────────────────────────────────────
          _NotificationCard(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColors.categoryMobility,
            title: 'Morning briefing',
            description: 'Daily AI summary of your health trends.',
            isEnabled: morningBriefingEnabled,
            onChanged: onMorningBriefingChanged,
            trailing: morningBriefingEnabled
                ? GestureDetector(
                    onTap: () => _pickTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusChip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(morningBriefingTime),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.edit_rounded,
                            color: AppColors.primary,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Smart Reminders ─────────────────────────────────────────────
          _NotificationCard(
            icon: Icons.notifications_active_rounded,
            iconColor: AppColors.categoryActivity,
            title: 'Smart reminders',
            description: 'Activity and hydration nudges based on your patterns.',
            isEnabled: smartRemindersEnabled,
            onChanged: onSmartRemindersChanged,
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Wellness Check-in ───────────────────────────────────────────
          _NotificationCard(
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

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
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
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isEnabled
            ? iconColor.withValues(alpha: 0.06)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: isEnabled ? iconColor.withValues(alpha: 0.3) : AppColors.borderDark,
        ),
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
                  style: AppTextStyles.h3
                      .copyWith(color: colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  trailing!,
                ],
              ],
            ),
          ),
          // Toggle switch.
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
