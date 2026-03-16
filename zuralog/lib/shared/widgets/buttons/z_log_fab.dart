/// Zuralog Design System — Log Floating Action Button.
///
/// A circular FAB with the app's primary colour and a "+" icon.
/// Pure UI component — no business logic. Debounce is the caller's
/// responsibility.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// Floating action button for opening the log grid sheet.
///
/// Pass this as the `floatingActionButton` parameter on [ZuralogScaffold].
/// [onPressed] is called on every tap — the caller must debounce if needed.
class ZLogFab extends StatelessWidget {
  const ZLogFab({super.key, required this.onPressed});

  /// Called when the FAB is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.primaryButtonText,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}
