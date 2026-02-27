/// Zuralog — Integration Context Provider.
///
/// Holds the metric label that triggered navigation to the Integrations tab
/// from a greyed-out dashboard metric tile. The Integrations screen watches
/// this provider to display a contextual "Connect a source for X" banner.
///
/// Lifecycle:
///   - Set when the user taps a no-data metric/card on the dashboard.
///   - Read and displayed by [IntegrationsHubScreen] as a top banner.
///   - Cleared either manually (dismiss button) or automatically after 10 s.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the metric label that should appear in the Integrations contextual
/// banner, or `null` when no banner should be shown.
///
/// Example usage (dashboard):
/// ```dart
/// ref.read(integrationContextProvider.notifier).state = 'Steps';
/// ```
///
/// Example usage (integrations screen):
/// ```dart
/// final label = ref.watch(integrationContextProvider);
/// if (label != null) { /* show banner */ }
/// ```
final integrationContextProvider = StateProvider<String?>((ref) => null);
