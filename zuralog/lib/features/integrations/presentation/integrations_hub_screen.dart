/// Zuralog — Integrations Hub Screen.
///
/// The main screen for managing third-party health and fitness service
/// connections. Organises integrations into three sections:
///   - **Connected** — services currently authorised and syncing.
///   - **Available** — supported services the user can connect.
///   - **Coming Soon** — upcoming integrations shown as a teaser.
///
/// Also displays a [CompatibleAppsSection] listing indirect integrations
/// (apps that sync through HealthKit / Health Connect).
///
/// Supports pull-to-refresh to reload the integration list and a search
/// bar that filters both direct and compatible app listings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/integrations/domain/compatible_apps_registry.dart';
import 'package:zuralog/features/integrations/domain/integration_context_provider.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_apps_section.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_tile.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integrations_search_bar.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// The Integrations Hub screen — connects and manages third-party services.
///
/// Observes [integrationsProvider] and categorises integrations into
/// Connected, Available, and Coming Soon sections. Empty sections are
/// hidden automatically.
///
/// A search bar (above the sections) filters both direct integrations and
/// the [CompatibleAppsSection]. When search is active and nothing matches
/// either list, a "No results for '...'" empty state is shown.
///
/// Lifecycle:
///   - On first mount, calls [IntegrationsNotifier.loadIntegrations].
///   - Pull-to-refresh re-calls [IntegrationsNotifier.loadIntegrations].
class IntegrationsHubScreen extends ConsumerStatefulWidget {
  /// Creates an [IntegrationsHubScreen].
  const IntegrationsHubScreen({super.key});

  @override
  ConsumerState<IntegrationsHubScreen> createState() =>
      _IntegrationsHubScreenState();
}

class _IntegrationsHubScreenState extends ConsumerState<IntegrationsHubScreen> {
  /// The current search query entered by the user.
  ///
  /// Updated via [setState] on every keystroke in [IntegrationsSearchBar].
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initial load is kicked automatically by the provider factory via
    // Future.microtask. No explicit call needed here — pull-to-refresh
    // (_onRefresh) handles manual reloads.

    // Auto-clear the contextual banner after 10 seconds if the user doesn't
    // dismiss it manually. We use a post-frame callback to ensure ref is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final label = ref.read(integrationContextProvider);
      if (label != null) {
        Future<void>.delayed(const Duration(seconds: 10), () {
          // Only clear if the same label is still showing (not replaced).
          if (mounted && ref.read(integrationContextProvider) == label) {
            ref.read(integrationContextProvider.notifier).state = null;
          }
        });
      }
    });
  }

  /// Handles pull-to-refresh gesture.
  Future<void> _onRefresh() async {
    await ref.read(integrationsProvider.notifier).loadIntegrations();
  }

  @override
  void dispose() {
    // Clear the context banner when the Integrations screen is fully removed
    // from the widget tree (e.g., the user logs out).
    // Note: for tab-switch scenarios, the 10-second auto-clear in initState
    // handles cleanup without requiring dispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(integrationsProvider);
    final integrations = state.integrations;
    final query = _searchQuery.toLowerCase().trim();

    // Watch the contextual banner label set by the dashboard.
    final String? contextLabel = ref.watch(integrationContextProvider);

    // ── Search filter predicate ──────────────────────────────────────────────
    bool matchesQuery(IntegrationModel i) =>
        query.isEmpty || i.name.toLowerCase().contains(query);

    // ── Partition into display sections (with search filter applied) ──────────
    final connected = integrations
        .where(
          (i) =>
              (i.status == IntegrationStatus.connected ||
                  i.status == IntegrationStatus.syncing) &&
              matchesQuery(i),
        )
        .toList();

    final available = integrations
        .where(
          (i) =>
              (i.status == IntegrationStatus.available ||
                  i.status == IntegrationStatus.error) &&
              matchesQuery(i),
        )
        .toList();

    final comingSoon = integrations
        .where(
          (i) => i.status == IntegrationStatus.comingSoon && matchesQuery(i),
        )
        .toList();

    // ── Derived display flags ─────────────────────────────────────────────────

    /// Whether any direct integration matches the current query.
    final hasDirectResults =
        connected.isNotEmpty || available.isNotEmpty || comingSoon.isNotEmpty;

    /// Compatible apps filtered by query (empty query → all apps).
    final compatibleApps = query.isEmpty
        ? CompatibleAppsRegistry.apps
        : CompatibleAppsRegistry.searchApps(query);
    final hasCompatibleResults = compatibleApps.isNotEmpty;

    /// Show the "no results" empty state only when search is active and
    /// nothing is found in either the direct or compatible lists.
    final showNoResults =
        query.isNotEmpty && !hasDirectResults && !hasCompatibleResults;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────────
            const SliverAppBar(
              title: Text('Integrations'),
              floating: true,
              pinned: false,
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: AppDimens.spaceMd),
                  child: ProfileAvatarButton(),
                ),
              ],
            ),

            // ── Search Bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: IntegrationsSearchBar(
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // ── Contextual "Connect a source for X" banner ────────────────────
            // Shown when the user navigated here by tapping a no-data metric.
            if (contextLabel != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceXs,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: AppDimens.iconSm,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.body.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                const TextSpan(text: 'Connect a source for '),
                                TextSpan(
                                  text: contextLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Dismiss button.
                        GestureDetector(
                          onTap: () => ref
                              .read(integrationContextProvider.notifier)
                              .state = null,
                          child: Icon(
                            Icons.close_rounded,
                            size: AppDimens.iconSm,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Connected Section ─────────────────────────────────────────────
            if (connected.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Connected'),
              _IntegrationListSliver(integrations: connected),
            ],

            // ── Available Section ─────────────────────────────────────────────
            if (available.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Available'),
              _IntegrationListSliver(integrations: available),
            ],

            // ── Coming Soon Section ───────────────────────────────────────────
            if (comingSoon.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Coming Soon'),
              _IntegrationListSliver(integrations: comingSoon),
            ],

            // ── Compatible Apps Section ───────────────────────────────────────
            // Omitted only when a search is active and nothing matches anywhere.
            if (!showNoResults)
              CompatibleAppsSection(searchQuery: _searchQuery),

            // ── No results empty state ────────────────────────────────────────
            if (showNoResults)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    "No results for '$_searchQuery'",
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            // ── Loading indicator ─────────────────────────────────────────────
            if (state.isLoading && integrations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),

            // ── Empty state (no integrations at all, not a search) ────────────
            if (integrations.isEmpty && !state.isLoading && query.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No integrations available.')),
              ),

            // ── Bottom padding for nav bar ────────────────────────────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.spaceXl),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header Sliver ──────────────────────────────────────────────────────

/// A [SliverToBoxAdapter] that renders a [SectionHeader] with padding.
class _SectionHeaderSliver extends StatelessWidget {
  /// Creates a [_SectionHeaderSliver] with the given [title].
  const _SectionHeaderSliver({required this.title});

  /// The section title text.
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceLg,
          AppDimens.spaceMd,
          AppDimens.spaceSm,
        ),
        child: SectionHeader(title: title),
      ),
    );
  }
}

// ── Integration List Sliver ────────────────────────────────────────────────────

/// A [SliverList] that renders a list of [IntegrationTile] widgets.
class _IntegrationListSliver extends StatelessWidget {
  /// Creates an [_IntegrationListSliver] for the given [integrations].
  const _IntegrationListSliver({required this.integrations});

  /// The integrations to render.
  final List<IntegrationModel> integrations;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => IntegrationTile(integration: integrations[index]),
        childCount: integrations.length,
      ),
    );
  }
}
