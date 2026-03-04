/// Notification Settings Screen — all push notification preferences.
///
/// Morning briefing, smart reminders, quiet hours, per-category toggles,
/// reminder frequency selector, streak/achievement/anomaly alerts.
/// All values persisted via /api/v1/preferences.
///
/// Full implementation: Phase 8, Task 8.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Local provider ─────────────────────────────────────────────────────────────

/// Holds local notification settings state (before persisting to backend).
@immutable
class _NotificationState {
  const _NotificationState({
    this.morningBriefingEnabled = true,
    this.morningBriefingTime = const TimeOfDay(hour: 7, minute: 0),
    this.smartRemindersEnabled = true,
    this.patternReminders = true,
    this.gapReminders = true,
    this.goalReminders = true,
    this.celebrationReminders = true,
    this.reminderFrequency = 2,
    this.streakReminders = true,
    this.achievementNotifications = true,
    this.anomalyAlerts = true,
    this.integrationAlerts = true,
    this.wellnessCheckinEnabled = true,
    this.wellnessCheckinTime = const TimeOfDay(hour: 20, minute: 0),
    this.quietHoursEnabled = false,
    this.quietHoursStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietHoursEnd = const TimeOfDay(hour: 7, minute: 0),
  });

  final bool morningBriefingEnabled;
  final TimeOfDay morningBriefingTime;
  final bool smartRemindersEnabled;
  final bool patternReminders;
  final bool gapReminders;
  final bool goalReminders;
  final bool celebrationReminders;
  final int reminderFrequency; // 1, 2, or 3 per day
  final bool streakReminders;
  final bool achievementNotifications;
  final bool anomalyAlerts;
  final bool integrationAlerts;
  final bool wellnessCheckinEnabled;
  final TimeOfDay wellnessCheckinTime;
  final bool quietHoursEnabled;
  final TimeOfDay quietHoursStart;
  final TimeOfDay quietHoursEnd;

  _NotificationState copyWith({
    bool? morningBriefingEnabled,
    TimeOfDay? morningBriefingTime,
    bool? smartRemindersEnabled,
    bool? patternReminders,
    bool? gapReminders,
    bool? goalReminders,
    bool? celebrationReminders,
    int? reminderFrequency,
    bool? streakReminders,
    bool? achievementNotifications,
    bool? anomalyAlerts,
    bool? integrationAlerts,
    bool? wellnessCheckinEnabled,
    TimeOfDay? wellnessCheckinTime,
    bool? quietHoursEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
  }) {
    return _NotificationState(
      morningBriefingEnabled:
          morningBriefingEnabled ?? this.morningBriefingEnabled,
      morningBriefingTime: morningBriefingTime ?? this.morningBriefingTime,
      smartRemindersEnabled:
          smartRemindersEnabled ?? this.smartRemindersEnabled,
      patternReminders: patternReminders ?? this.patternReminders,
      gapReminders: gapReminders ?? this.gapReminders,
      goalReminders: goalReminders ?? this.goalReminders,
      celebrationReminders: celebrationReminders ?? this.celebrationReminders,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      streakReminders: streakReminders ?? this.streakReminders,
      achievementNotifications:
          achievementNotifications ?? this.achievementNotifications,
      anomalyAlerts: anomalyAlerts ?? this.anomalyAlerts,
      integrationAlerts: integrationAlerts ?? this.integrationAlerts,
      wellnessCheckinEnabled:
          wellnessCheckinEnabled ?? this.wellnessCheckinEnabled,
      wellnessCheckinTime: wellnessCheckinTime ?? this.wellnessCheckinTime,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}

final _notificationStateProvider =
    StateProvider<_NotificationState>((_) => const _NotificationState());

// ── NotificationSettingsScreen ────────────────────────────────────────────────

/// Notification preferences screen — toggles, time pickers, frequency selector.
class NotificationSettingsScreen extends ConsumerWidget {
  /// Creates the [NotificationSettingsScreen].
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_notificationStateProvider);
    final notifier = ref.read(_notificationStateProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);

    void trackToggle(String setting, bool enabled) => analytics.capture(
          event: AnalyticsEvents.notificationSettingChanged,
          properties: {'setting': setting, 'enabled': enabled},
        );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        children: [
          // ── Morning Briefing ───────────────────────────────────────────
          _SectionLabel('Morning Briefing'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.wb_sunny_rounded,
                iconColor: AppColors.categoryNutrition,
                title: 'Morning Briefing',
                subtitle: 'Daily AI-generated health summary',
                value: state.morningBriefingEnabled,
                onChanged: (v) {
                  notifier.state = state.copyWith(morningBriefingEnabled: v);
                  trackToggle('morning_briefing', v);
                },
              ),
              if (state.morningBriefingEnabled) ...[
                _Divider(),
                _TimePickerRow(
                  icon: Icons.access_time_rounded,
                  iconColor: AppColors.categoryNutrition,
                  title: 'Briefing Time',
                  time: state.morningBriefingTime,
                  onChanged: (t) =>
                      notifier.state = state.copyWith(morningBriefingTime: t),
                ),
              ],
            ],
          ),

          // ── Smart Reminders ────────────────────────────────────────────
          _SectionLabel('Smart Reminders'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.primary,
                title: 'Smart Reminders',
                subtitle: 'AI-personalized nudges based on your patterns',
                value: state.smartRemindersEnabled,
                onChanged: (v) {
                  notifier.state = state.copyWith(smartRemindersEnabled: v);
                  trackToggle('smart_reminders', v);
                },
              ),
              if (state.smartRemindersEnabled) ...[
                _Divider(),
                _SubToggleRow(
                  title: 'Pattern-based',
                  subtitle: 'Reminders based on your behavior history',
                  value: state.patternReminders,
                  onChanged: (v) {
                    notifier.state = state.copyWith(patternReminders: v);
                    trackToggle('pattern_reminders', v);
                  },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Data gaps',
                  subtitle: 'Remind when expected data is missing',
                  value: state.gapReminders,
                  onChanged: (v) {
                    notifier.state = state.copyWith(gapReminders: v);
                    trackToggle('gap_reminders', v);
                  },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Goal progress',
                  subtitle: 'Nudges when you\'re close to your goals',
                  value: state.goalReminders,
                  onChanged: (v) {
                    notifier.state = state.copyWith(goalReminders: v);
                    trackToggle('goal_reminders', v);
                  },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Celebrations',
                  subtitle: 'Positive milestones and personal bests',
                  value: state.celebrationReminders,
                  onChanged: (v) {
                    notifier.state = state.copyWith(celebrationReminders: v);
                    trackToggle('celebration_reminders', v);
                  },
                ),
                _Divider(),
                _FrequencyRow(
                  value: state.reminderFrequency,
                  onChanged: (v) {
                    notifier.state = state.copyWith(reminderFrequency: v);
                    analytics.capture(
                      event: AnalyticsEvents.notificationFrequencyChanged,
                      properties: {
                        'frequency': v == 1 ? 'low' : v == 2 ? 'medium' : 'high',
                      },
                    );
                  },
                ),
              ],
            ],
          ),

          // ── Activity Notifications ────────────────────────────────────
          _SectionLabel('Activity Notifications'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.categoryHeart,
                title: 'Streak Reminders',
                subtitle: 'Keep your streaks alive',
                value: state.streakReminders,
                onChanged: (v) {
                  notifier.state = state.copyWith(streakReminders: v);
                  trackToggle('streak_reminders', v);
                },
              ),
              _Divider(),
              _ToggleRow(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.categoryNutrition,
                title: 'Achievement Unlocked',
                subtitle: 'Celebrate new badges',
                value: state.achievementNotifications,
                onChanged: (v) {
                  notifier.state = state.copyWith(achievementNotifications: v);
                  trackToggle('achievement_notifications', v);
                },
              ),
              _Divider(),
              _ToggleRow(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.statusConnecting,
                title: 'Anomaly Alerts',
                subtitle: 'Critical health metric deviations',
                value: state.anomalyAlerts,
                onChanged: (v) {
                  notifier.state = state.copyWith(anomalyAlerts: v);
                  trackToggle('anomaly_alerts', v);
                },
              ),
              _Divider(),
              _ToggleRow(
                icon: Icons.sync_problem_rounded,
                iconColor: AppColors.categoryBody,
                title: 'Integration Alerts',
                subtitle: 'When a connected app stops syncing',
                value: state.integrationAlerts,
                onChanged: (v) {
                  notifier.state = state.copyWith(integrationAlerts: v);
                  trackToggle('integration_alerts', v);
                },
              ),
            ],
          ),

          // ── Wellness Check-in ─────────────────────────────────────────
          _SectionLabel('Wellness Check-in'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.self_improvement_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Daily Check-in Reminder',
                subtitle: 'Log mood, energy, and water intake',
                value: state.wellnessCheckinEnabled,
                onChanged: (v) {
                  notifier.state = state.copyWith(wellnessCheckinEnabled: v);
                  trackToggle('wellness_checkin', v);
                },
              ),
              if (state.wellnessCheckinEnabled) ...[
                _Divider(),
                _TimePickerRow(
                  icon: Icons.access_time_rounded,
                  iconColor: AppColors.categoryWellness,
                  title: 'Check-in Time',
                  time: state.wellnessCheckinTime,
                  onChanged: (t) =>
                      notifier.state = state.copyWith(wellnessCheckinTime: t),
                ),
              ],
            ],
          ),

          // ── Quiet Hours ───────────────────────────────────────────────
          _SectionLabel('Quiet Hours'),
          _SettingsCard(
            children: [
              _ToggleRow(
                icon: Icons.do_not_disturb_on_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Quiet Hours',
                subtitle: 'Silence all notifications during set hours',
                value: state.quietHoursEnabled,
                onChanged: (v) {
                  notifier.state = state.copyWith(quietHoursEnabled: v);
                  trackToggle('quiet_hours', v);
                },
              ),
              if (state.quietHoursEnabled) ...[
                _Divider(),
                _TimePickerRow(
                  icon: Icons.bedtime_rounded,
                  iconColor: AppColors.categorySleep,
                  title: 'Start',
                  time: state.quietHoursStart,
                  onChanged: (t) =>
                      notifier.state = state.copyWith(quietHoursStart: t),
                ),
                _Divider(),
                _TimePickerRow(
                  icon: Icons.wb_twilight_rounded,
                  iconColor: AppColors.categorySleep,
                  title: 'End',
                  time: state.quietHoursEnd,
                  onChanged: (t) =>
                      notifier.state = state.copyWith(quietHoursEnd: t),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: AppColors.borderDark.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.borderDark,
          ),
        ],
      ),
    );
  }
}

class _SubToggleRow extends StatelessWidget {
  const _SubToggleRow({
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
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimens.spaceXxl,
        right: AppDimens.spaceMd,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.borderDark,
          ),
        ],
      ),
    );
  }
}

class _FrequencyRow extends StatelessWidget {
  const _FrequencyRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Max Reminders Per Day',
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              _FrequencyChip(
                label: 'Low\n1/day',
                selected: value == 1,
                onTap: () => onChanged(1),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _FrequencyChip(
                label: 'Medium\n2/day',
                selected: value == 2,
                onTap: () => onChanged(2),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              _FrequencyChip(
                label: 'High\n3/day',
                selected: value == 3,
                onTap: () => onChanged(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceSm,
            horizontal: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatTime(time);
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: AppColors.primaryButtonText,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: Text(
                formatted,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
