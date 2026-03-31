/// Zuralog Design System — Dimension & Spacing Tokens.
///
/// Consistent spacing based on a 4px base grid.
/// Corner radii, shadow definitions, and sizing constants.
library;

import 'package:flutter/material.dart';

/// Spacing, radius, shadow, and sizing constants for the Zuralog design system.
///
/// All spacing values follow a 4px base grid for visual consistency.
/// Radii and shadows match the view-design.md Section 1.3 specification.
abstract final class AppDimens {
  // ── Spacing (4px base grid) ───────────────────────────────────────────────

  /// 2px — double extra-small spacing (tight inline gaps, e.g. emoji-to-value).
  static const double spaceXxs = 2;

  /// 4px — extra-small spacing (icon gaps, tight padding).
  static const double spaceXs = 4;

  /// 8px — small spacing (between related elements).
  static const double spaceSm = 8;

  /// 16px — medium spacing (standard padding inside cards).
  static const double spaceMd = 16;

  /// 20px — medium-plus spacing (feature card padding, nav bar margin).
  static const double spaceMdPlus = 20;

  /// 24px — large spacing (between sections).
  static const double spaceLg = 24;

  /// 32px — extra-large spacing (screen-level padding).
  static const double spaceXl = 32;

  /// 48px — double extra-large spacing (hero sections, large gaps).
  static const double spaceXxl = 48;

  // ── Corner Radii ─────────────────────────────────────────────────────────

  /// Card corner radius — 20px per AGENTS.md design system specification.
  static const double radiusCard = 20;

  /// Button corner radius — pill-shaped (fully rounded).
  static const double radiusButton = 100;

  /// Medium button corner radius — 14px per AGENTS.md primary action spec.
  static const double radiusButtonMd = 14;

  /// Input field corner radius.
  static const double radiusInput = 12;

  /// Chip/badge/integration rail pill radius.
  static const double radiusChip = 16;

  /// Small element radius (e.g., status dots, avatars).
  static const double radiusSm = 8;

  // ── AppShapes — Shape Scale (v3.2) ────────────────────────────────────────
  // All shape tokens map to BorderRadius.circular(value).
  // New code should use these shape-scale constants; the legacy radius*
  // constants above are kept as aliases for backwards compatibility.

  /// 8px — chips, tags, small badges, tooltip arrows.
  static const double shapeXs = 8;

  /// 12px — input fields, tooltips, snackbars.
  static const double shapeSm = 12;

  /// 16px — metric tiles, compact cards, data cards.
  static const double shapeMd = 16;

  /// 20px — feature cards, hero cards.
  static const double shapeLg = 20;

  /// 28px — bottom sheets (top corners), modals, dialogs.
  static const double shapeXl = 28;

  /// 100px — all buttons: primary, secondary, ghost (aliases radiusButton).
  static const double shapePill = 100;

  // ── Shadows (Light mode only) ─────────────────────────────────────────────
  //
  // Dark mode uses no shadows — only 1px borders on cards.
  // The border is defined in AppTheme and applied by ZuralogCard.

  /// Card shadow — light mode only.
  ///
  /// Matches view-design.md spec: 0px 4px 20px rgba(0,0,0,0.05).
  static const List<BoxShadow> cardShadowLight = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  // ── Sizing ────────────────────────────────────────────────────────────────

  /// Minimum touch target dimension (48px for Android, iOS recommends 44px).
  /// Using 48px to satisfy the stricter Android guideline universally.
  static const double touchTargetMin = 48;

  /// Bottom navigation bar height.
  static const double bottomNavHeight = 80;

  /// Standard medium icon size.
  static const double iconMd = 24;

  /// Small icon size.
  static const double iconSm = 16;

  /// Small icon container size — 36x36 (goal trajectory card icon box).
  static const double iconContainerSm = 36;

  /// Medium icon container size — 44x44 (next achievement card icon box).
  static const double iconContainerMd = 44;

  /// Large icon container size — 72x72 (streak flame hero circle).
  static const double iconContainerLg = 72;

  /// Avatar — large (48px).
  static const double avatarLg = 48;

  /// Avatar — medium (36px).
  static const double avatarMd = 36;

  /// Avatar — small (24px).
  static const double avatarSm = 24;

  /// Integration rail item width (pill-shaped cards).
  static const double integrationPillWidth = 120;

  /// Integration rail pill tile height.
  static const double integrationPillHeight = 64;

  /// Integration rail scrollable row height (pill + breathing room).
  static const double integrationRailHeight = 84;

  /// Health ring outer diameter.
  static const double ringDiameter = 180;

  /// Small emoji display size (in logical pixels) — used in compact tiles.
  static const double emojiSm = 16;

  /// Standard emoji display size (in logical pixels).
  static const double emojiMd = 32;

  // ── Opacity ───────────────────────────────────────────────────────────────

  /// Opacity for ghost/inactive states (e.g. ghost flame in zero-streak card).
  static const double ghostOpacity = 0.22;

  /// Opacity for disabled/pinned interactive elements.
  static const double disabledOpacity = 0.45;

  // ── Navigation Bar ────────────────────────────────────────────────────────

  /// Navigation bar backdrop blur intensity (sigmaX and sigmaY).
  static const double navBarBlurSigma = 20;

  /// Navigation bar frosted glass background opacity.
  static const double navBarFrostOpacity = 0.92;

  // ── Layout Helpers ────────────────────────────────────────────────────────

  /// Bottom clearance for content inside tabs.
  ///
  /// [AppShell] uses `extendBody: true` on its [Scaffold], which causes
  /// Flutter to automatically inject the frosted nav bar's rendered height
  /// into [MediaQuery.padding.bottom] for all children of the body. This
  /// means [MediaQuery.padding.bottom] already equals:
  ///
  /// ```
  ///   nav bar height  +  system safe-area (home indicator, gesture bar, etc.)
  /// ```
  ///
  /// We therefore return [MediaQuery.padding.bottom] directly — adding
  /// [bottomNavHeight] on top would double-count the nav bar and produce a
  /// visible ~80 px dead-space gap above the frosted nav bar on every tab.
  ///
  /// Use this wherever content inside the shell needs bottom breathing room
  /// so it is not obscured by the frosted nav bar.
  static double bottomClearance(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;
}
