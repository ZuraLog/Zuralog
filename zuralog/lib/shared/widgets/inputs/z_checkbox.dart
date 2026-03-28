/// Zuralog Design System — Checkbox Component.
///
/// Custom-painted checkbox with Sage fill and pattern overlay when checked.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant;

/// A brand-styled checkbox.
///
/// When checked, fills with Sage (#CFE1B9) plus a topographic pattern and
/// shows a dark checkmark (#1A2E22). When unchecked, shows a textSecondary
/// border with transparent fill.
///
/// The visual box is 20x20 but the hit area is 44x44 for accessibility.
class ZCheckbox extends StatefulWidget {
  const ZCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.label,
  });

  /// Whether the checkbox is checked.
  final bool value;

  /// Called when the user taps the checkbox. Null disables interaction.
  final ValueChanged<bool>? onChanged;

  /// Whether the checkbox is interactive.
  final bool enabled;

  /// Optional label shown to the right of the checkbox.
  final String? label;

  @override
  State<ZCheckbox> createState() => _ZCheckboxState();
}

class _ZCheckboxState extends State<ZCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(ZCheckbox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onChanged == null) return;
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final checkbox = Semantics(
      checked: widget.value,
      label: widget.label ?? '',
      enabled: widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // Background — sage pattern when checked, border when unchecked.
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: progress < 1.0
                                ? Border.all(
                                    color: Color.lerp(
                                      colors.textSecondary,
                                      Colors.transparent,
                                      progress,
                                    )!,
                                    width: 2,
                                  )
                                : null,
                            image: progress > 0
                                ? DecorationImage(
                                    image: AssetImage(
                                        ZPatternVariant.sage.assetPath),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                        ),
                        // Fade-in for the pattern during transition.
                        if (progress > 0 && progress < 1.0)
                          Opacity(
                            opacity: 1.0 - progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        // Checkmark icon.
                        if (progress > 0.3)
                          Center(
                            child: Opacity(
                              opacity: ((progress - 0.3) / 0.7).clamp(0, 1),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: AppColors.textOnSage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ),
    );

    if (widget.label == null) return checkbox;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          checkbox,
          Text(
            widget.label!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
