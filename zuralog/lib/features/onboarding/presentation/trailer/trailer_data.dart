/// Zuralog Onboarding — Trailer Slide Data.
///
/// The three slides shown on first launch. Copy and photo paths are
/// intentional — do not shuffle order without design review.
library;

/// A single trailer slide: one photo, one headline.
class TrailerSlide {
  const TrailerSlide({required this.imageAsset, required this.headline});
  final String imageAsset;
  final String headline;
}

/// The three slides, in order.
const List<TrailerSlide> trailerSlides = [
  TrailerSlide(
    imageAsset: 'assets/welcome/trailer_01.jpg',
    headline: "Know why you're tired.",
  ),
  TrailerSlide(
    imageAsset: 'assets/welcome/trailer_02.jpg',
    headline: 'Know why you feel great.',
  ),
  TrailerSlide(
    imageAsset: 'assets/welcome/trailer_03.jpg',
    headline: 'Know what to change.',
  ),
];
