/// Zuralog — Compatible Apps Collapsible Section.
///
/// A sliver section for the Integrations Hub displaying compatible
/// third-party health/fitness apps that sync through HealthKit or
/// Health Connect.
///
/// The section is collapsed by default. When [searchQuery] is non-empty
/// the section auto-expands to show matching results.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/compatible_apps_registry.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_app_tile.dart';

/// A collapsible section listing all compatible health/fitness apps.
///
/// Shows the app count in the header. When [searchQuery] is non-empty,
/// filters the list and auto-expands.
///
/// Use as a [SliverToBoxAdapter] child in a [CustomScrollView].
///
/// Parameters:
///   searchQuery: Optional filter string. Filters by app name.
class CompatibleAppsSection extends StatefulWidget {
  /// Creates a [CompatibleAppsSection].
  const CompatibleAppsSection({super.key, this.searchQuery = ''});

  /// Optional search query to filter compatible apps by name.
  final String searchQuery;

  @override
  State<CompatibleAppsSection> createState() => _CompatibleAppsSectionState();
}

class _CompatibleAppsSectionState extends State<CompatibleAppsSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand immediately when the widget is created with a non-empty query.
    if (widget.searchQuery.isNotEmpty) {
      _expanded = true;
    }
  }

  @override
  void didUpdateWidget(CompatibleAppsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-expand when a search becomes active after the initial build.
    // Intentionally does NOT auto-collapse when search is cleared — once the
    // user has opened the section (either manually or via search), it stays
    // open for the remainder of the session so results aren't hidden on clear.
    if (widget.searchQuery.isNotEmpty && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final apps = widget.searchQuery.isEmpty
        ? CompatibleAppsRegistry.apps
        : CompatibleAppsRegistry.searchApps(widget.searchQuery);

    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Section header / toggle ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Compatible Apps (${apps.length})',
                      style: AppTextStyles.h3.copyWith(color: cs.onSurface),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded list ────────────────────────────────────────────────
          if (_expanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apps.length,
              itemBuilder: (context, index) =>
                  CompatibleAppTile(app: apps[index]),
            ),
        ],
      ),
    );
  }
}
