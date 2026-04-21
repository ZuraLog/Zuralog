/// Pure helpers for the Data tab's one-line plain-English summary.
library;

import 'package:zuralog/features/data/domain/data_models.dart';

/// Picks the single plain-English line rendered under the hero value
/// on a `ZCategorySummaryCard`.
///
/// Resolution order:
/// 1. Non-blank [aiHeadline] — reuse the Today-tab insight voice when available.
/// 2. Delta-bucket phrase computed from [todayValue] vs. [weekAverage].
/// 3. `'No data yet.'` when either input is null or average is zero.
///
/// For categories where a lower value is better (resting heart rate), the
/// direction of the delta is flipped so "better" always maps to the upper
/// buckets.
String categorySummaryFor({
  required HealthCategory category,
  required double? todayValue,
  required double? weekAverage,
  String? aiHeadline,
}) {
  final headline = aiHeadline?.trim();
  if (headline != null && headline.isNotEmpty) return headline;

  if (todayValue == null || weekAverage == null || weekAverage == 0) {
    return 'No data yet.';
  }

  var delta = (todayValue - weekAverage) / weekAverage;
  if (_lowerIsBetter(category)) delta = -delta;

  if (delta >= 0.15) return 'Best this week.';
  if (delta >= 0.02) return 'Slightly better than your usual.';
  if (delta >= -0.02) return 'Right on your usual.';
  if (delta >= -0.15) return 'A bit below lately.';
  return 'Lower than your usual.';
}

bool _lowerIsBetter(HealthCategory category) {
  switch (category) {
    case HealthCategory.heart:
      return true;
    default:
      return false;
  }
}
