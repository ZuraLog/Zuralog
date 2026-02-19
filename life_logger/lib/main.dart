/// Life Logger Edge Agent — Application Entry Point.
///
/// Initializes Flutter bindings and wraps the app in a Riverpod
/// [ProviderScope] for dependency injection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_logger/app.dart';

/// Application entry point.
///
/// Ensures Flutter bindings are initialized before running the app.
/// The [ProviderScope] at the root enables Riverpod state management
/// throughout the entire widget tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LifeLoggerApp()));
}
