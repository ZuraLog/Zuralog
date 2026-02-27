/// Zuralog — Integrations Search Bar Widget.
///
/// A styled search text field for filtering integrations (both direct and
/// compatible apps) in the Integrations Hub screen.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A search bar that filters integrations by name.
///
/// Includes a search icon prefix, "Search integrations..." placeholder,
/// and a clear button that appears when text is entered.
///
/// Parameters:
///   onChanged: Called with the current query string on every keystroke.
class IntegrationsSearchBar extends StatefulWidget {
  /// Creates an [IntegrationsSearchBar].
  const IntegrationsSearchBar({super.key, required this.onChanged});

  /// Callback invoked with the search query on every text change.
  final ValueChanged<String> onChanged;

  @override
  State<IntegrationsSearchBar> createState() => _IntegrationsSearchBarState();
}

class _IntegrationsSearchBarState extends State<IntegrationsSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onClear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: AppTextStyles.body.copyWith(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Search integrations...',
          hintStyle: AppTextStyles.body.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: cs.onSurfaceVariant,
          ),
          suffixIcon: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.clear_rounded, color: cs.onSurfaceVariant),
                onPressed: _onClear,
              );
            },
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceSm,
          ),
        ),
      ),
    );
  }
}
