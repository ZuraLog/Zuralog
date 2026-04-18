/// Zuralog — Integrations Search Bar Widget.
///
/// A styled search text field for filtering integrations (both direct and
/// compatible apps) in the Integrations Hub screen.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/inputs/z_search_bar.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: ZSearchBar(
        controller: _controller,
        placeholder: 'Search integrations...',
        onChanged: widget.onChanged,
        onClear: _onClear,
      ),
    );
  }
}
