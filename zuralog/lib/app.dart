/// Zuralog Edge Agent — Root Application Widget.
///
/// Configures the [MaterialApp] with the Zuralog design system themes
/// (light/dark/system-native) and connects the [themeModeProvider] so
/// the UI responds to both system preference changes and user overrides
/// from the Settings screen.
///
/// During Phase 2.1, the home screen remains the [HarnessScreen] for
/// design system verification. Production routing (GoRouter + screens)
/// will replace this in Phase 2.2 / 2.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/harness/harness_screen.dart';

/// The root widget of the Zuralog application.
///
/// Extends [ConsumerWidget] (not [StatelessWidget]) to watch the
/// [themeModeProvider] and rebuild [MaterialApp] when the theme mode
/// changes. This is the correct Riverpod pattern — only the widget that
/// needs the state rebuilds.
class ZuralogApp extends ConsumerWidget {
  /// Creates the root [ZuralogApp] widget.
  const ZuralogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Zuralog',
      debugShowCheckedModeBanner: false,
      // Light and dark themes from the design system.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Defaults to ThemeMode.system — follows the device's OS setting.
      // Overridable from the Settings screen via themeModeProvider.
      themeMode: themeMode,
      home: const HarnessScreen(),
    );
  }
}
