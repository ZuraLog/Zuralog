/// Zuralog Edge Agent — Shared Preferences Provider.
///
/// Provides a singleton [SharedPreferences] instance via Riverpod so that
/// any widget or service can access persistent key-value storage through
/// [ref.read(prefsProvider)] instead of calling the async
/// [SharedPreferences.getInstance()] ad-hoc throughout the codebase.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a singleton [SharedPreferences] instance.
///
/// Must be overridden in [main.dart] before [runApp] is called:
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(ProviderScope(
///   overrides: [prefsProvider.overrideWithValue(prefs)],
///   child: const App(),
/// ));
/// ```
///
/// Use [ref.read(prefsProvider)] instead of
/// [SharedPreferences.getInstance()] anywhere in the widget tree.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'prefsProvider must be overridden with a SharedPreferences instance '
    'before runApp is called. See main.dart.',
  );
});
