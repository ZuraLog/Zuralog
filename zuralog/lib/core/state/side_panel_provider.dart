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

/// Whether the profile side panel is currently open (target state).
///
/// `true` = panel is open (sliding in or fully open).
/// `false` = panel is closed (sliding out or fully hidden).
final sidePanelOpenProvider = StateProvider<bool>((ref) => false);

/// Whether the panel node is present in the Stack.
///
/// Stays `true` for the duration of the close animation so the
/// [AnimatedSlide] can finish playing before the node is removed.
/// Stored in Riverpod (not widget state) so it survives GoRouter rebuilds.
final sidePanelVisibleProvider = StateProvider<bool>((ref) => false);
