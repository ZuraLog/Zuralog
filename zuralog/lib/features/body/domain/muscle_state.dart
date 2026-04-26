/// Per-muscle readiness state used by the Your-Body-Now hero.
///
/// - [fresh]   — primed, no recent load
/// - [worked]  — loaded in the last 72h, mildly fatigued
/// - [sore]    — high recent load or user-reported soreness
/// - [neutral] — no signal (new account, no integrations, or muscle never trained)
library;

enum MuscleState {
  fresh(slug: 'fresh', label: 'Fresh'),
  worked(slug: 'worked', label: 'Worked'),
  sore(slug: 'sore', label: 'Sore'),
  neutral(slug: 'neutral', label: 'Neutral');

  const MuscleState({required this.slug, required this.label});

  final String slug;
  final String label;

  static MuscleState fromSlug(String input) {
    for (final s in MuscleState.values) {
      if (s.slug == input) return s;
    }
    return MuscleState.neutral;
  }
}
