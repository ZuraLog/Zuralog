/// Zuralog — Integration Logo Widget.
///
/// Renders a branded logo for a third-party integration.
///
/// Resolution order for each integration [id]:
///   1. A recognised brand icon from [simple_icons] or [font_awesome_flutter]
///      via the hardcoded switch (Strava, Garmin, Fitbit, Apple Health,
///      Google Health Connect).
///   2. A [simple_icons] icon looked up dynamically via [simpleIconSlug],
///      tinted with [brandColorValue].
///   3. An asset image if [logoAsset] is provided and the file loads.
///   4. A coloured circle with two-letter initials as the final fallback,
///      using [brandColorValue] as background when provided.
///
/// This design avoids bundling image assets in the app package entirely,
/// keeping the install size small while still showing recognisable brand icons.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:simple_icons/simple_icons.dart';

import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Brand colour map ──────────────────────────────────────────────────────────

/// Maps each hardcoded integration [id] to its canonical brand colour.
///
/// Used to tint the vector icon so it matches the real-world brand even
/// when rendered in a monochrome icon font.
const Map<String, Color> _kBrandColors = {
  'strava': Color(0xFFFC4C02),                // Strava orange
  'garmin': Color(0xFF1A73E8),                // Garmin blue
  'fitbit': Color(0xFF00B0B9),                // Fitbit teal
  'apple_health': Color(0xFF000000),          // Apple black (inverted on dark)
  'google_health_connect': Color(0xFF4285F4), // Google blue
};

// ── SimpleIcons slug lookup table ─────────────────────────────────────────────

/// Maps known [simpleIconSlug] values to their [SimpleIcons] icon data.
///
/// Only slugs used by compatible apps in [CompatibleAppsRegistry] are listed.
/// Add more entries here when new compatible apps are registered.
///
/// IMPORTANT: Every entry here has been verified to exist as a static field on
/// [SimpleIcons] in version 14.6.1 of the `simple_icons` package. Do not add
/// slugs that are not compiled into that version.
const Map<String, IconData> _kSimpleIconsBySlug = {
  'adidas': SimpleIcons.adidas,
  'alltrails': SimpleIcons.alltrails,
  'eightsleep': SimpleIcons.eightsleep,
  'fitbit': SimpleIcons.fitbit,
  'garmin': SimpleIcons.garmin,
  'google': SimpleIcons.google,
  'headspace': SimpleIcons.headspace,
  'komoot': SimpleIcons.komoot,
  'nike': SimpleIcons.nike,
  'samsung': SimpleIcons.samsung,
  'strava': SimpleIcons.strava,
};

// ── Icon resolver ─────────────────────────────────────────────────────────────

/// Describes a resolved brand icon for display.
class _BrandIcon {
  const _BrandIcon({required this.data, this.isFontAwesome = false});

  /// The icon glyph.
  final IconData data;

  /// Whether this icon requires [FaIcon] instead of the Material [Icon] widget.
  final bool isFontAwesome;
}

/// Returns a [_BrandIcon] for a known hardcoded integration [id], or `null`
/// when no icon is available for that id.
_BrandIcon? _brandIconForId(String id) {
  switch (id) {
    case 'strava':
      return const _BrandIcon(data: SimpleIcons.strava);
    case 'garmin':
      return const _BrandIcon(data: SimpleIcons.garmin);
    case 'fitbit':
      return const _BrandIcon(data: SimpleIcons.fitbit);
    case 'apple_health':
      return const _BrandIcon(
        data: FontAwesomeIcons.apple,
        isFontAwesome: true,
      );
    case 'google_health_connect':
      return const _BrandIcon(data: SimpleIcons.google);
    default:
      return null;
  }
}

// ── IntegrationLogo ───────────────────────────────────────────────────────────

/// Displays the logo for a third-party integration.
///
/// Tries icon fonts first (no bundled assets needed), then a dynamic
/// [simpleIconSlug] lookup, then an optional [logoAsset] image path,
/// then a coloured initials circle fallback.
///
/// Parameters:
///   id: The integration identifier (e.g. `'strava'`, `'apple_health'`).
///   name: The integration display name — used for the initials fallback.
///   logoAsset: Optional asset path (rarely needed; icon fonts are preferred).
///   size: Diameter of the rendered logo area in logical pixels (default 40).
///   simpleIconSlug: Optional slug for a [SimpleIcons] icon (e.g. `'nike'`).
///     When provided and the slug is found in [_kSimpleIconsBySlug], the icon
///     is rendered tinted with [brandColorValue].
///   brandColorValue: ARGB integer colour (e.g. `0xFF514689`). Used as the
///     icon tint when [simpleIconSlug] is resolved, or as the background colour
///     for the initials circle fallback when no icon is available.
class IntegrationLogo extends StatelessWidget {
  /// Creates an [IntegrationLogo].
  const IntegrationLogo({
    super.key,
    required this.id,
    required this.name,
    this.logoAsset,
    this.size = 40,
    this.simpleIconSlug,
    this.brandColorValue,
  });

  /// The integration identifier used to resolve the brand icon and colour.
  final String id;

  /// Integration display name used to derive initials for the fallback.
  final String name;

  /// Optional asset path — only used when no icon font entry exists for [id].
  ///
  /// When `null` (or when the asset fails to load) the initials circle is
  /// rendered instead.
  final String? logoAsset;

  /// Width and height of the rendered logo area in logical pixels.
  final double size;

  /// Optional slug for a dynamic [SimpleIcons] lookup (e.g. `'nike'`).
  ///
  /// When provided and found in [_kSimpleIconsBySlug], the matching icon is
  /// rendered tinted with [brandColorValue] (or grey if not provided).
  /// Unrecognised slugs fall through to the asset / initials fallback.
  final String? simpleIconSlug;

  /// ARGB colour integer (e.g. `0xFF514689`) used as:
  ///   - The icon tint when [simpleIconSlug] resolves to an icon.
  ///   - The background colour for the initials circle fallback.
  ///
  /// When `null`, a hash-derived palette colour is used for the initials
  /// background and grey (`0xFF888888`) is used for icon tints.
  final int? brandColorValue;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // ── 1. Hardcoded brand icon from switch ─────────────────────────────────
    final hardcoded = _brandIconForId(id);
    if (hardcoded != null) {
      final Color rawColor = _kBrandColors[id] ?? const Color(0xFF888888);
      final Color iconColor =
          (id == 'apple_health' && isDark) ? Colors.white : rawColor;
      return _iconWidget(hardcoded, iconColor);
    }

    // ── 2. Dynamic simpleIconSlug lookup ────────────────────────────────────
    final slug = simpleIconSlug;
    if (slug != null) {
      final iconData = _kSimpleIconsBySlug[slug];
      if (iconData != null) {
        final Color iconColor = brandColorValue != null
            ? Color(brandColorValue!)
            : const Color(0xFF888888);
        return _iconWidget(_BrandIcon(data: iconData), iconColor);
      }
    }

    // ── 3. Asset image ───────────────────────────────────────────────────────
    final asset = logoAsset;
    if (asset != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _InitialsFallback(
            name: name,
            size: size,
            brandColorValue: brandColorValue,
          ),
        ),
      );
    }

    // ── 4. Initials circle fallback ──────────────────────────────────────────
    return _InitialsFallback(
      name: name,
      size: size,
      brandColorValue: brandColorValue,
    );
  }

  /// Renders a brand icon with [color] tint at the widget's [size].
  ///
  /// Parameters:
  ///   brand: The resolved [_BrandIcon] describing the glyph and font pack.
  ///   color: The tint colour to apply to the icon.
  ///
  /// Returns: A [SizedBox] containing a centred [FaIcon] or [Icon].
  Widget _iconWidget(_BrandIcon brand, Color color) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: brand.isFontAwesome
            ? FaIcon(brand.data, color: color, size: size * 0.65)
            : Icon(brand.data, color: color, size: size * 0.65),
      ),
    );
  }
}

// ── Initials Fallback ─────────────────────────────────────────────────────────

/// Fallback widget rendered when no brand icon or asset image is available.
///
/// Shows a coloured circle with the first two letters of [name].
/// Uses [brandColorValue] as the background colour when provided,
/// otherwise derives a deterministic colour from [name].
class _InitialsFallback extends StatelessWidget {
  /// Creates an [_InitialsFallback] for [name] at the given [size].
  const _InitialsFallback({
    required this.name,
    required this.size,
    this.brandColorValue,
  });

  /// Integration name used to derive the two-letter initials.
  final String name;

  /// Diameter of the circle in logical pixels.
  final double size;

  /// Optional ARGB colour integer for the circle background.
  ///
  /// When `null`, a hash-derived colour from the palette is used instead.
  final int? brandColorValue;

  /// Derives a colour for the circle background.
  ///
  /// Parameters:
  ///   name: The integration display name.
  ///
  /// Returns: [brandColorValue] as a [Color] if provided, otherwise a
  ///   deterministic colour from the hash palette.
  Color _colorForName(String name) {
    // If a brand color is provided, use it directly.
    if (brandColorValue != null) return Color(brandColorValue!);
    // Otherwise fall back to the hash-derived palette.
    const colors = [
      Color(0xFFE07A5F),
      Color(0xFF3D405B),
      Color(0xFF81B29A),
      Color(0xFFF2CC8F),
      Color(0xFF5B8DB8),
      Color(0xFF9B59B6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  /// Returns the first 1–2 characters of [name] as upper-case initials.
  ///
  /// Parameters:
  ///   name: The integration display name.
  ///
  /// Returns: A 1–2 character upper-case string (e.g. `'ST'` for `'Strava'`).
  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorForName(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: (size * 0.35).clamp(10, 18),
        ),
      ),
    );
  }
}
