/// Composite recovery score shown in the hero rail.
library;

class ReadinessScore {
  const ReadinessScore({
    this.value,
    this.delta,
    this.hrvNormalized,
    this.rhrNormalized,
    this.sleepNormalized,
  });

  /// 0–100. Null when no component signals are available.
  final int? value;

  /// Difference vs the user's 7-day average. Null if no history.
  final int? delta;

  /// Component values normalized to 0–100 against the user's 28-day baseline.
  final double? hrvNormalized;
  final double? rhrNormalized;
  final double? sleepNormalized;

  static const ReadinessScore empty = ReadinessScore();

  bool get hasSignal => value != null;

  static int clamp(num raw) {
    if (raw < 0) return 0;
    if (raw > 100) return 100;
    return raw.round();
  }
}
