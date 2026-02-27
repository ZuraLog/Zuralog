/// Zuralog Dashboard — Health Category Enum.
///
/// Defines the ten top-level categories that organise every health metric
/// tracked by Zuralog. Each category carries display metadata (name, icon,
/// accent colour) so that UI code can render category headers, chips, and
/// filter pills without hard-coding presentation details.
///
/// Colour palette sourced from the Dashboard Enhancement Plan v2.
library;

import 'package:flutter/material.dart';

/// The ten top-level categories that group all health metrics.
///
/// Every [HealthMetric] belongs to exactly one category. The category
/// determines the default accent colour, section icon, and grouping
/// in the metric-picker / detail screens.
enum HealthCategory {
  /// Steps, calories, distance, exercise sessions, cycling, running, etc.
  activity(
    displayName: 'Activity',
    icon: Icons.directions_run_rounded,
    accentColor: Color(0xFFCFE1B9),
  ),

  /// Weight, body fat, BMI, height, lean body mass, etc.
  body(
    displayName: 'Body Measurements',
    icon: Icons.accessibility_new_rounded,
    accentColor: Color(0xFF5B7C99),
  ),

  /// Heart rate, resting HR, HRV, VO2 max, etc.
  heart(
    displayName: 'Heart',
    icon: Icons.favorite_rounded,
    accentColor: Color(0xFFE07A5F),
  ),

  /// Blood pressure, respiratory rate, SpO2, blood glucose, etc.
  vitals(
    displayName: 'Vitals',
    icon: Icons.monitor_heart_rounded,
    accentColor: Color(0xFFE74C3C),
  ),

  /// Sleep duration and sleep stages.
  sleep(
    displayName: 'Sleep',
    icon: Icons.bedtime_rounded,
    accentColor: Color(0xFF7B68EE),
  ),

  /// Calories consumed, macronutrients, micronutrients, hydration.
  nutrition(
    displayName: 'Nutrition',
    icon: Icons.restaurant_rounded,
    accentColor: Color(0xFF9B59B6),
  ),

  /// Menstruation, ovulation, cervical mucus, basal body temp, etc.
  cycle(
    displayName: 'Cycle Tracking',
    icon: Icons.water_drop_rounded,
    accentColor: Color(0xFFFF69B4),
  ),

  /// Mindfulness sessions, skin temperature, state of mind.
  wellness(
    displayName: 'Wellness',
    icon: Icons.self_improvement_rounded,
    accentColor: Color(0xFF2ECC71),
  ),

  /// Walking speed, steadiness, stair speed — Apple-only metrics.
  mobility(
    displayName: 'Mobility',
    icon: Icons.directions_walk_rounded,
    accentColor: Color(0xFFF39C12),
  ),

  /// UV exposure, audio exposure, water temperature — Apple-only.
  environment(
    displayName: 'Environment',
    icon: Icons.wb_sunny_rounded,
    accentColor: Color(0xFF3498DB),
  );

  /// Creates a [HealthCategory] value with its display metadata.
  const HealthCategory({
    required this.displayName,
    required this.icon,
    required this.accentColor,
  });

  /// Human-readable label for UI display (e.g. "Activity", "Body Measurements").
  final String displayName;

  /// Material icon representing this category in lists, headers, and chips.
  final IconData icon;

  /// Brand accent colour for this category, used on graphs, headers, and chips.
  final Color accentColor;
}
