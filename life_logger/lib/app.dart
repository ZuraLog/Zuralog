/// Life Logger Edge Agent — Root Application Widget.
///
/// Configures the MaterialApp and sets the initial screen to the
/// developer test harness (Phase 1). In Phase 2, this will be replaced
/// with GoRouter navigation and the production design system.
library;

import 'package:flutter/material.dart';

import 'package:life_logger/features/harness/harness_screen.dart';

/// The root widget of the Life Logger application.
///
/// During Phase 1 (backend-first), the home screen is the raw
/// [HarnessScreen] for functional verification. The production
/// UI will be wired in Phase 2.
class LifeLoggerApp extends StatelessWidget {
  /// Creates the root [LifeLoggerApp] widget.
  const LifeLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Life Logger', home: const HarnessScreen());
  }
}
