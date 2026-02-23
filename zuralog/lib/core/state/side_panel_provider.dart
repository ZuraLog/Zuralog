/// Zuralog — Side Panel State Provider.
///
/// Exposes a simple [StateProvider<bool>] that controls whether the profile
/// side panel is open or closed. The provider lives at the app-shell level so
/// that both the [AppShell] (which animates the push-reveal) and any child
/// widget (e.g. the dashboard avatar) can read and mutate the state.
///
/// Usage:
/// ```dart
/// // Open the panel from any widget:
/// ref.read(sidePanelOpenProvider.notifier).state = true;
///
/// // Close from any widget:
/// ref.read(sidePanelOpenProvider.notifier).state = false;
///
/// // Watch in AppShell to drive animation:
/// final isOpen = ref.watch(sidePanelOpenProvider);
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the profile side panel is currently visible.
///
/// `true` = panel is open (app shell slid left, panel visible on right).
/// `false` = panel is closed (normal layout).
final sidePanelOpenProvider = StateProvider<bool>((ref) => false);
