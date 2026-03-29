/// Zuralog Design System — Accordion Component.
///
/// A vertically stacked list of expandable sections, wrapped in a Surface card.
/// Each item has a title header with a rotating chevron indicator and
/// smoothly animated content reveal.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/z_divider.dart';

/// A single expandable section used inside [ZAccordion].
///
/// Each item renders a tappable header row with a chevron that rotates 180
/// degrees when the section opens. The content slides in with a smooth height
/// animation.
class ZAccordionItem {
  /// Creates an accordion item.
  const ZAccordionItem({
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  /// Header text shown in every collapsed or expanded state.
  final String title;

  /// The widget revealed when the section is expanded.
  final Widget content;

  /// Whether this section starts open. Defaults to `false`.
  final bool initiallyExpanded;
}

/// A grouped list of collapsible sections inside a Surface card.
///
/// Uses [AppDimens.shapeLg] (20px) rounded corners, Surface (#1E1E20)
/// background, and brand dividers between items.
///
/// ```dart
/// ZAccordion(
///   items: [
///     ZAccordionItem(title: 'What is Zuralog?', content: Text('...')),
///     ZAccordionItem(title: 'How do I connect?', content: Text('...')),
///   ],
/// )
/// ```
class ZAccordion extends StatelessWidget {
  /// Creates an accordion with the given [items].
  const ZAccordion({super.key, required this.items});

  /// The expandable sections to display.
  final List<ZAccordionItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const ZDivider(),
              _AccordionSection(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal stateful widget that manages the expand/collapse state and
/// chevron rotation for a single accordion section.
class _AccordionSection extends StatefulWidget {
  const _AccordionSection({required this.item});

  final ZAccordionItem item;

  @override
  State<_AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<_AccordionSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late final AnimationController _controller;
  late final Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.item.initiallyExpanded;
    _controller = AnimationController(
      duration: AppMotion.durationMedium,
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _chevronTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curveTransition),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header row ──────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: AppDimens.spaceMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _chevronTurns,
                  child: Icon(
                    Icons.expand_more,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expandable content ──────────────────────────────────────────
        AnimatedSize(
          duration: AppMotion.durationMedium,
          curve: AppMotion.curveTransition,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ZDivider(),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppDimens.spaceMd,
                        right: AppDimens.spaceMd,
                        top: AppDimens.spaceSm,
                        bottom: AppDimens.spaceMd,
                      ),
                      child: widget.item.content,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
