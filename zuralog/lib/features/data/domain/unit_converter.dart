/// Zuralog — Unit Display Converter.
///
/// Maps API unit strings to user-facing display labels based on the
/// user's [UnitsSystem] preference.
///
/// NOTE: This maps unit *labels* only — numeric value conversion is a
/// separate future task (tracked in TODO comments at call sites).
library;

import 'package:zuralog/features/settings/domain/user_preferences_model.dart';

/// Returns the display label for [apiUnit] given the user's [system].
///
/// For [UnitsSystem.metric], the API unit is returned unchanged.
///
/// For [UnitsSystem.imperial], known metric units are mapped to their
/// imperial equivalents.
///
/// TODO: P2 — add numeric value conversion for imperial display.
String displayUnit(String apiUnit, UnitsSystem system) {
  // Note: kJ (kilojoules) is returned as-is for both metric and imperial users.
  // Displaying 'kcal' without numeric conversion would misrepresent the value
  // (1 kJ ≈ 0.239 kcal). See TODO below for deferred numeric conversion.

  if (system == UnitsSystem.metric) return apiUnit;

  // Imperial label mappings
  return switch (apiUnit) {
    'kg'   => 'lbs',
    'km'   => 'mi',
    'cm'   => 'in',
    '°C'   => '°F',
    // TODO: numeric conversion required before display (1 ml ≈ 0.034 fl oz; 1 L ≈ 33.8 fl oz)
    'ml'   => 'fl oz',
    'L'    => 'fl oz',
    'g'    => 'oz',
    'm'    => 'ft',
    'm/s'  => 'mph',
    'km/h' => 'mph',
    // mmHg, kPa, %, bpm, steps, etc. are the same in both systems
    _      => apiUnit,
  };
}
