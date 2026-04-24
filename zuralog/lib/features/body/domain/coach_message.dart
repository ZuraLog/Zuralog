library;

import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

class CoachMessage {
  const CoachMessage({
    required this.text,
    required this.ctaLabel,
    required this.ctaRoute,
    this.isCheckIn = false,
    this.checkInMuscleGroup,
  });

  /// Plain-language message from Zura (2 sentences max).
  final String text;

  /// Label on the call-to-action (e.g. "View session").
  final String ctaLabel;

  /// go_router path the CTA should navigate to.
  final String ctaRoute;

  /// True when this message is a next-morning soreness check-in.
  final bool isCheckIn;

  /// For single-muscle check-in: the muscle to pre-highlight in the picker.
  final MuscleGroup? checkInMuscleGroup;
}
