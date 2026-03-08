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
/// For [UnitsSystem.metric], the API unit is returned unchanged
/// (except for system-agnostic normalizations like kJ → kcal).
///
/// For [UnitsSystem.imperial], known metric units are mapped to their
/// imperial equivalents.
///
/// TODO: P2 — add numeric value conversion for imperial display.
String displayUnit(String apiUnit, UnitsSystem system) {
  // System-agnostic display normalization: nutrition apps universally display
  // energy in kcal regardless of unit system preference.
  if (apiUnit == 'kJ') return 'kcal';

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
