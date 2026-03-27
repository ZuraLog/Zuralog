/// Zuralog Design System — Search Bar Component.
///
/// A styled search input with Surface fill, pattern overlay, search icon,
/// and clear button.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A brand-styled search bar.
///
/// Surface fill with a subtle topographic pattern overlay, a search icon on
/// the left, and a clear (X) button that appears when text is not empty.
/// Gains a Sage border on focus.
class ZSearchBar extends StatefulWidget {
  const ZSearchBar({
    super.key,
    this.controller,
    this.placeholder = 'Search...',
    this.onChanged,
    this.onClear,
  });

  /// Controller for the search text field.
  final TextEditingController? controller;

  /// Placeholder text shown when the field is empty.
  final String placeholder;

  /// Called on every character change.
  final ValueChanged<String>? onChanged;

  /// Called when the user taps the clear button.
  final VoidCallback? onClear;

  @override
  State<ZSearchBar> createState() => _ZSearchBarState();
}

class _ZSearchBarState extends State<ZSearchBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sageFocusBorder = AppColors.primary.withValues(alpha: 0.3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      child: Stack(
        children: [
          // The text field.
          TextFormField(
            controller: _controller,
            cursorColor: AppColors.primary,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
            ),
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surface,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _hasText
                  ? GestureDetector(
                      onTap: _handleClear,
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm + 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                borderSide: BorderSide(color: sageFocusBorder, width: 1.5),
              ),
            ),
          ),
          // Pattern overlay on the background.
          const Positioned.fill(
            child: IgnorePointer(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.05,
                blendMode: BlendMode.screen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
