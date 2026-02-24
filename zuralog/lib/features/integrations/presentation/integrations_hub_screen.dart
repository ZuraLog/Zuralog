/// Zuralog — Integrations Hub Screen.
///
/// The main screen for managing third-party health and fitness service
/// connections. Organises integrations into three sections:
///   - **Connected** — services currently authorised and syncing.
///   - **Available** — supported services the user can connect.
///   - **Coming Soon** — upcoming integrations shown as a teaser.
///
/// Supports pull-to-refresh to reload the integration list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_tile.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// The Integrations Hub screen — connects and manages third-party services.
///
/// Observes [integrationsProvider] and categorises integrations into
/// Connected, Available, and Coming Soon sections. Empty sections are
/// hidden automatically.
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
  @override
  void initState() {
    super.initState();
    // Initial load is kicked automatically by the provider factory via
    // Future.microtask. No explicit call needed here — pull-to-refresh
    // (_onRefresh) handles manual reloads.
  }

  /// Handles pull-to-refresh gesture.
  Future<void> _onRefresh() async {
    await ref.read(integrationsProvider.notifier).loadIntegrations();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(integrationsProvider);
    final integrations = state.integrations;

    // Partition into display sections.
    final connected = integrations
        .where(
          (i) =>
              i.status == IntegrationStatus.connected ||
              i.status == IntegrationStatus.syncing,
        )
        .toList();

    final available = integrations
        .where(
          (i) =>
              i.status == IntegrationStatus.available ||
              i.status == IntegrationStatus.error,
        )
        .toList();

    final comingSoon = integrations
        .where((i) => i.status == IntegrationStatus.comingSoon)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
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

            // ── Connected Section ────────────────────────────────────────
            if (connected.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Connected'),
              _IntegrationListSliver(integrations: connected),
            ],

            // ── Available Section ────────────────────────────────────────
            if (available.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Available'),
              _IntegrationListSliver(integrations: available),
            ],

            // ── Coming Soon Section ──────────────────────────────────────
            if (comingSoon.isNotEmpty) ...[
              _SectionHeaderSliver(title: 'Coming Soon'),
              _IntegrationListSliver(integrations: comingSoon),
            ],

            // ── Loading indicator ─────────────────────────────────────────
            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),

            // ── Empty state (list loaded but genuinely empty) ─────────────
            if (integrations.isEmpty && !state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No integrations available.')),
              ),

            // ── Bottom padding for nav bar ───────────────────────────────
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
