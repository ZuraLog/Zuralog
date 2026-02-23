/// Zuralog Design System — Theme Mode Provider.
///
/// Manages the app's [ThemeMode] via Riverpod state management.
/// Defaults to [ThemeMode.system] to respect the user's device preference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that holds the current [ThemeMode] for the application.
///
/// Defaults to [ThemeMode.system], which follows the device's appearance
/// setting automatically (light or dark based on OS preference).
///
/// Can be overridden via the Settings screen to force [ThemeMode.light]
/// or [ThemeMode.dark] regardless of the system setting.
///
/// Usage in a widget:
/// ```dart
/// final themeMode = ref.watch(themeModeProvider);
/// ```
///
/// Usage in a controller to update:
/// ```dart
/// ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
/// ```
final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
  name: 'themeModeProvider',
);
