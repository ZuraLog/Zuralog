/// Zuralog Design System — Motion & Spring Token System.
///
/// Defines the `AppMotion` spring presets used for all animations in the
/// Zuralog v3.2 design language. Implements the M3 Expressive motion
/// philosophy: physics-based springs with intentional overshoot for spatial
/// movement, and critically-damped springs for appearance changes.
///
/// All spring constants use pre-calculated damping values since Dart `const`
/// does not allow `dart:math`'s `sqrt()` at compile time.
///
/// ## Spring categories
///
/// ### Spatial springs (dampingRatio < 1.0 — slight overshoot)
/// Used for position, scale, and size changes. The underdamped overshoot
/// makes movement feel alive and physical.
///
/// | Token         | Damping ratio | Stiffness | Typical use                       |
/// |---------------|--------------|-----------|-----------------------------------|
/// | fastSpatial   | 0.6          | 1400      | Button press, chip select, icon   |
/// | defaultSpatial| 0.7          | 700       | Card entry, panel slide, hero     |
/// | slowSpatial   | 0.8          | 300       | Ring fill, large hero scale-in    |
///
/// ### Effects springs (dampingRatio = 1.0 — critically damped, no oscillation)
/// Used for opacity, color, and blur changes. Color/opacity should not
/// oscillate — they must arrive cleanly without bouncing.
///
/// | Token          | Damping ratio | Stiffness | Typical use                    |
/// |----------------|--------------|-----------|--------------------------------|
/// | fastEffects    | 1.0          | 3800      | Tap feedback, icon color       |
/// | defaultEffects | 1.0          | 1600      | Text fade, badge reveal        |
/// | slowEffects    | 1.0          | 800       | Skeleton→content crossfade     |
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Spring description constants for the Zuralog animation system.
///
/// All values are `SpringDescription(mass: 1, stiffness: k, damping: c)`
/// where `c = 2 * dampingRatio * sqrt(stiffness)` pre-calculated as:
///
/// - fastSpatial:    c = 2 * 0.6 * sqrt(1400) ≈ 44.9
/// - defaultSpatial: c = 2 * 0.7 * sqrt(700)  ≈ 37.1
/// - slowSpatial:    c = 2 * 0.8 * sqrt(300)  ≈ 27.7
/// - fastEffects:    c = 2 * 1.0 * sqrt(3800) ≈ 123.3
/// - defaultEffects: c = 2 * 1.0 * sqrt(1600) ≈ 80.0
/// - slowEffects:    c = 2 * 1.0 * sqrt(800)  ≈ 56.6
abstract final class AppMotion {
  // ── Duration-Based Tokens (Brand Bible) ──────────────────────────────────
  // Simple duration + curve combos for straightforward animations.

  /// 150ms — micro-interactions: button press, toggle flip, checkbox check.
  static const Duration durationFast = Duration(milliseconds: 150);

  /// 250ms — standard transitions: card expand, chip select, dropdown open.
  static const Duration durationMedium = Duration(milliseconds: 250);

  /// 350ms — major transitions: screen push, bottom sheet slide, modal appear.
  static const Duration durationSlow = Duration(milliseconds: 350);

  /// 600ms — staggered entrances: card feed loading, list population.
  static const Duration durationEntrance = Duration(milliseconds: 600);

  /// Easing for elements appearing (fast start, gentle stop).
  static const Curve curveEntrance = Curves.easeOut;

  /// Easing for elements disappearing (slow start, fast finish).
  static const Curve curveExit = Curves.easeIn;

  /// Easing for transitions that both enter and leave.
  static const Curve curveTransition = Curves.easeInOut;

  /// Stagger delay between cascading card animations (60ms per card).
  static const Duration staggerDelay = Duration(milliseconds: 60);

  // ── Spatial Springs ────────────────────────────────────────────────────────
  // Underdamped (ratio < 1.0) — slight overshoot before settling.
  // Use for position, scale, and size transitions.

  /// Fast spatial spring — stiffness 1400, damping ratio 0.6.
  ///
  /// Used for: button press scale, chip selection, icon morphs.
  /// Settles in ~200ms with a small but perceptible overshoot.
  static const SpringDescription fastSpatial = SpringDescription(
    mass: 1,
    stiffness: 1400,
    damping: 44.9,
  );

  /// Default spatial spring — stiffness 700, damping ratio 0.7.
  ///
  /// Used for: card entry, screen transitions, panel slides, hero entrances.
  /// Settles in ~350ms with a natural overshoot.
  static const SpringDescription defaultSpatial = SpringDescription(
    mass: 1,
    stiffness: 700,
    damping: 37.1,
  );

  /// Slow spatial spring — stiffness 300, damping ratio 0.8.
  ///
  /// Used for: progress ring fill, large hero scale-in, backdrop reveals.
  /// Settles in ~500ms with a gentle overshoot.
  static const SpringDescription slowSpatial = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 27.7,
  );

  // ── Effects Springs ────────────────────────────────────────────────────────
  // Critically damped (ratio = 1.0) — no oscillation.
  // Use for opacity, color, and blur transitions.

  /// Fast effects spring — stiffness 3800, damping ratio 1.0.
  ///
  /// Used for: tap feedback, icon color change, state layer transitions.
  /// Settles in ~80ms, no overshoot.
  static const SpringDescription fastEffects = SpringDescription(
    mass: 1,
    stiffness: 3800,
    damping: 123.3,
  );

  /// Default effects spring — stiffness 1600, damping ratio 1.0.
  ///
  /// Used for: text fade, badge reveal, shimmer end transitions.
  /// Settles in ~150ms, no overshoot.
  static const SpringDescription defaultEffects = SpringDescription(
    mass: 1,
    stiffness: 1600,
    damping: 80.0,
  );

  /// Slow effects spring — stiffness 800, damping ratio 1.0.
  ///
  /// Used for: skeleton → content crossfade, background tint transitions.
  /// Settles in ~250ms, no overshoot.
  static const SpringDescription slowEffects = SpringDescription(
    mass: 1,
    stiffness: 800,
    damping: 56.6,
  );
}
