/// Message displayed in the hero's coach strip.
library;

class CoachMessage {
  const CoachMessage({
    required this.text,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  /// Plain-language message from Zura (≤ 2 sentences).
  final String text;

  /// Label on the call-to-action (e.g. "View session").
  final String ctaLabel;

  /// go_router path the CTA should navigate to.
  final String ctaRoute;
}
