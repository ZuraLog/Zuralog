/// Shared formatting helpers for metric values displayed on the Today tab.
///
/// Used by both [today_providers.dart] (snapshot cards) and
/// [today_feed_screen.dart] (metric grid tiles).
library;

/// Formats a step count into a compact string.
///
/// Values >= 1000 are shown as e.g. "8.3k"; smaller values are shown as-is.
String formatSteps(int steps) {
  if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
  return steps.toString();
}

/// Formats a sleep duration in minutes into a "Xh Ym" string.
///
/// e.g. 450 → "7h 30m"
String formatSleepMinutes(double minutes) {
  final h = (minutes / 60).floor();
  final m = (minutes % 60).toInt();
  return '${h}h ${m}m';
}
