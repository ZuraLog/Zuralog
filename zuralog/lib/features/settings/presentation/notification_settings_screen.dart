/// Notification Settings Screen — all push notification preferences.
///
/// Morning briefing, smart reminders, quiet hours, per-category toggles,
/// reminder frequency selector, streak/achievement/anomaly alerts.
///
/// ## Fixes applied (settings-mapping remediation)
/// Previously, all 17 notification preferences lived in an in-memory
/// [_NotificationState] that reset on every cold start. The screen's doc
/// comment said "All values persisted via /api/v1/preferences" but the
/// save call was never implemented.
///
/// Now:
/// - [initState] seeds [_notificationStateProvider] from the loaded
///   [userPreferencesProvider] so the screen opens with the user's actual
///   saved preferences.
/// - Every toggle/time-picker change calls
///   [UserPreferencesNotifier.mutate] to immediately persist via the
///   optimistic-write pattern (SharedPreferences + API PATCH).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/analytics/feature_flag_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

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
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the [NotificationSettingsScreen].
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Seed local state from the global preferences (loaded from API/cache).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = ref.read(userPreferencesProvider).valueOrNull;
      if (prefs != null) {
        final notifSettings = prefs.notificationSettings;
        ref.read(_notificationStateProvider.notifier).state =
            _NotificationState(
          morningBriefingEnabled: prefs.morningBriefingEnabled,
          morningBriefingTime: prefs.morningBriefingTime ??
              const TimeOfDay(hour: 7, minute: 0),
          smartRemindersEnabled: notifSettings.smartRemindersEnabled,
          patternReminders: notifSettings.patternReminders,
          gapReminders: notifSettings.gapReminders,
          goalReminders: notifSettings.goalReminders,
          celebrationReminders: notifSettings.celebrationReminders,
          reminderFrequency: notifSettings.reminderFrequency,
          streakReminders: notifSettings.streakReminders,
          achievementNotifications: notifSettings.achievementNotifications,
          anomalyAlerts: notifSettings.anomalyAlerts,
          integrationAlerts: notifSettings.integrationAlerts,
          wellnessCheckinEnabled: prefs.checkinReminderEnabled,
          wellnessCheckinTime: prefs.checkinReminderTime ??
              const TimeOfDay(hour: 20, minute: 0),
          quietHoursEnabled: prefs.quietHoursEnabled,
          quietHoursStart: prefs.quietHoursStart ??
              const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: prefs.quietHoursEnd ??
              const TimeOfDay(hour: 7, minute: 0),
        );
      }

      // Seed reminder frequency from PostHog feature flag only if the
      // user has never customised it (still at the default of 2).
      ref
          .read(featureFlagServiceProvider)
          .notificationFrequencyDefault()
          .then((freq) {
        if (!mounted) return;
        final currentState = ref.read(_notificationStateProvider);
        if (currentState.reminderFrequency == 2) {
          ref.read(_notificationStateProvider.notifier).state =
              currentState.copyWith(reminderFrequency: freq);
        }
      });
    });
  }

  // ── Persist helper ─────────────────────────────────────────────────────────

  /// Persists the current local [_NotificationState] to [userPreferencesProvider].
  void _persist(_NotificationState s) {
    ref.read(userPreferencesProvider.notifier).mutate(
          (p) => p.copyWith(
            morningBriefingEnabled: s.morningBriefingEnabled,
            morningBriefingTime: s.morningBriefingTime,
            checkinReminderEnabled: s.wellnessCheckinEnabled,
            checkinReminderTime: s.wellnessCheckinTime,
            quietHoursEnabled: s.quietHoursEnabled,
            quietHoursStart: s.quietHoursStart,
            quietHoursEnd: s.quietHoursEnd,
            notificationSettings: NotificationSettings(
              smartRemindersEnabled: s.smartRemindersEnabled,
              patternReminders: s.patternReminders,
              gapReminders: s.gapReminders,
              goalReminders: s.goalReminders,
              celebrationReminders: s.celebrationReminders,
              reminderFrequency: s.reminderFrequency,
              streakReminders: s.streakReminders,
              achievementNotifications: s.achievementNotifications,
              anomalyAlerts: s.anomalyAlerts,
              integrationAlerts: s.integrationAlerts,
            ),
          ),
        );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_notificationStateProvider);
    final notifier = ref.read(_notificationStateProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);

    void trackToggle(String setting, bool enabled) => analytics.capture(
          event: AnalyticsEvents.notificationSettingChanged,
          properties: {'setting': setting, 'enabled': enabled},
        );

    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Notifications'),
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
                  final updated = state.copyWith(morningBriefingEnabled: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  onChanged: (t) {
                    final updated = state.copyWith(morningBriefingTime: t);
                    notifier.state = updated;
                    _persist(updated);
                  },
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
                  final updated = state.copyWith(smartRemindersEnabled: v);
                  notifier.state = updated;
                  _persist(updated);
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
                      final updated = state.copyWith(patternReminders: v);
                      notifier.state = updated;
                      _persist(updated);
                      trackToggle('pattern_reminders', v);
                    },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Data gaps',
                  subtitle: 'Remind when expected data is missing',
                    value: state.gapReminders,
                    onChanged: (v) {
                      final updated = state.copyWith(gapReminders: v);
                      notifier.state = updated;
                      _persist(updated);
                      trackToggle('gap_reminders', v);
                    },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Goal progress',
                  subtitle: 'Nudges when you\'re close to your goals',
                    value: state.goalReminders,
                    onChanged: (v) {
                      final updated = state.copyWith(goalReminders: v);
                      notifier.state = updated;
                      _persist(updated);
                      trackToggle('goal_reminders', v);
                    },
                ),
                _Divider(),
                _SubToggleRow(
                  title: 'Celebrations',
                  subtitle: 'Positive milestones and personal bests',
                    value: state.celebrationReminders,
                    onChanged: (v) {
                      final updated =
                          state.copyWith(celebrationReminders: v);
                      notifier.state = updated;
                      _persist(updated);
                      trackToggle('celebration_reminders', v);
                    },
                ),
                _Divider(),
                _FrequencyRow(
                  value: state.reminderFrequency,
                  onChanged: (v) {
                    final updated = state.copyWith(reminderFrequency: v);
                    notifier.state = updated;
                    _persist(updated);
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
                  final updated = state.copyWith(streakReminders: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  final updated =
                      state.copyWith(achievementNotifications: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  final updated = state.copyWith(anomalyAlerts: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  final updated = state.copyWith(integrationAlerts: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  final updated = state.copyWith(wellnessCheckinEnabled: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  onChanged: (t) {
                    final updated = state.copyWith(wellnessCheckinTime: t);
                    notifier.state = updated;
                    _persist(updated);
                  },
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
                  final updated = state.copyWith(quietHoursEnabled: v);
                  notifier.state = updated;
                  _persist(updated);
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
                  onChanged: (t) {
                    final updated = state.copyWith(quietHoursStart: t);
                    notifier.state = updated;
                    _persist(updated);
                  },
                ),
                _Divider(),
                _TimePickerRow(
                  icon: Icons.wb_twilight_rounded,
                  iconColor: AppColors.categorySleep,
                  title: 'End',
                  time: state.quietHoursEnd,
                  onChanged: (t) {
                    final updated = state.copyWith(quietHoursEnd: t);
                    notifier.state = updated;
                    _persist(updated);
                  },
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
        style: AppTextStyles.labelSmall.copyWith(
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
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
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
                  style: AppTextStyles.bodySmall.copyWith(
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
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
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
            style: AppTextStyles.bodySmall.copyWith(
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
                style: AppTextStyles.bodyLarge.copyWith(
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
                style: AppTextStyles.bodySmall.copyWith(
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
