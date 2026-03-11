/// Profile Screen.
///
/// User avatar, display name, email, member-since date, subscription tier badge,
/// inline edit for display name, Emergency Health Card link, gear → Settings.
///
/// Full implementation: Phase 8, Task 8.10.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Local state ───────────────────────────────────────────────────────────────

@immutable
class _ProfileState {
  const _ProfileState({
    // TODO(auth): Wire displayName, email, memberSince, and tier to the
    // authenticated user provider from core/di/ once the auth layer is
    // connected (Phase 9). These defaults are empty placeholders only.
    this.displayName = '',
    this.email = '',
    this.memberSince = '',
    this.tier = 'Free',
    this.isEditingName = false,
  });

  final String displayName;
  final String email;
  final String memberSince;
  final String tier;
  final bool isEditingName;

  _ProfileState copyWith({
    String? displayName,
    String? email,
    String? memberSince,
    String? tier,
    bool? isEditingName,
  }) =>
      _ProfileState(
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        memberSince: memberSince ?? this.memberSince,
        tier: tier ?? this.tier,
        isEditingName: isEditingName ?? this.isEditingName,
      );
}

final _profileStateProvider =
    StateProvider<_ProfileState>((_) => const _ProfileState());

// ── ProfileScreen ─────────────────────────────────────────────────────────────

/// Profile screen — identity, subscription tier, Emergency Health Card,
/// quick edit for display name, and access to Settings.
class ProfileScreen extends ConsumerWidget {
  /// Creates the [ProfileScreen].
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_profileStateProvider);

    return ZuralogScaffold(
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar with gear icon ──────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.settings_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Settings',
                onPressed: () => context.pushNamed(RouteNames.settings),
              ),
              const SizedBox(width: AppDimens.spaceXs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: 14,
              ),
              collapseMode: CollapseMode.parallax,
              title: Text(
                'Profile',
                style: AppTextStyles.displaySmall,
              ),
            ),
          ),

          // ── Avatar & identity card ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                0,
              ),
              child: _IdentityCard(profile: profile),
            ),
          ),

          // ── Emergency Health Card link ───────────────────────────────────
          const SliverToBoxAdapter(child: SettingsSectionLabel('HEALTH & SAFETY')),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: const _EmergencyCardBanner(),
            ),
          ),

          // ── Account section ──────────────────────────────────────────────
          const SliverToBoxAdapter(child: SettingsSectionLabel('ACCOUNT')),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: _AccountGroup(tier: profile.tier),
            ),
          ),

          // ── Activity stats ───────────────────────────────────────────────
          const SliverToBoxAdapter(child: SettingsSectionLabel('ACTIVITY')),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: const _ActivityStatsCard(),
            ),
          ),

          // ── Sign out ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceXxl,
              ),
              child: _SignOutButton(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _IdentityCard ──────────────────────────────────────────────────────────────

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.profile});

  final _ProfileState profile;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEdit() {
    _nameController.text = widget.profile.displayName;
    ref.read(_profileStateProvider.notifier).state =
        widget.profile.copyWith(isEditingName: true);
  }

  void _saveEdit() {
    final name = _nameController.text.trim();
    ref.read(_profileStateProvider.notifier).state = widget.profile.copyWith(
      displayName: name.isNotEmpty ? name : widget.profile.displayName,
      isEditingName: false,
    );
  }

  void _cancelEdit() {
    ref.read(_profileStateProvider.notifier).state =
        widget.profile.copyWith(isEditingName: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final profile = ref.watch(_profileStateProvider);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          // Avatar with camera badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'AR',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.background,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // Display name (editable inline)
          if (profile.isEditingName)
            _NameEditRow(
              controller: _nameController,
              onSave: _saveEdit,
              onCancel: _cancelEdit,
            )
          else
            GestureDetector(
              onTap: _startEdit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.displayName,
                    style: AppTextStyles.displaySmall.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppDimens.spaceXs),

          // Email
          Text(
            profile.email,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // Tier badge + member-since
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TierBadge(tier: profile.tier),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                  'Member since ${profile.memberSince}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _NameEditRow ───────────────────────────────────────────────────────────────

class _NameEditRow extends StatelessWidget {
  const _NameEditRow({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceSm,
              ),
              filled: true,
              fillColor: colors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusInput),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => onSave(),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        IconButton(
          icon: const Icon(Icons.check_rounded, color: AppColors.primary),
          onPressed: onSave,
          tooltip: 'Save',
        ),
        IconButton(
          icon:
              const Icon(Icons.close_rounded, color: AppColors.textTertiary),
          onPressed: onCancel,
          tooltip: 'Cancel',
        ),
      ],
    );
  }
}

// ── _TierBadge ─────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final String tier;

  Color _color(AppColorsOf colors) {
    switch (tier) {
      case 'Pro':
        return AppColors.primary;
      case 'Premium':
        return AppColors.categoryMobility;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final tierColor = _color(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(color: tierColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: tierColor),
          const SizedBox(width: 3),
          Text(
            tier,
            style: AppTextStyles.bodySmall.copyWith(
              color: tierColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _EmergencyCardBanner ───────────────────────────────────────────────────────

class _EmergencyCardBanner extends StatelessWidget {
  const _EmergencyCardBanner();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogSpringButton(
      onTap: () => context.pushNamed(RouteNames.emergencyCard),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.categoryHeart.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border:
              Border.all(color: AppColors.categoryHeart.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const ZIconBadge(
              icon: Icons.medical_information_rounded,
              color: AppColors.categoryHeart,
              size: 44,
              iconSize: 24,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Health Card',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Blood type, allergies, medications & emergency contacts',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _AccountGroup ──────────────────────────────────────────────────────────────

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          ZSettingsTile(
            icon: Icons.settings_rounded,
            iconColor: colors.textSecondary,
            title: 'Settings',
            subtitle: 'Notifications, appearance, coach & more',
            onTap: () => context.pushNamed(RouteNames.settings),
          ),
          const _Divider(),
          ZSettingsTile(
            icon: Icons.workspace_premium_rounded,
            iconColor: AppColors.categoryMobility,
            title: 'Subscription',
            subtitle: '$tier plan',
            onTap: () => context.pushNamed(RouteNames.settingsSubscription),
          ),
          const _Divider(),
          ZSettingsTile(
            icon: Icons.person_rounded,
            iconColor: AppColors.categoryBody,
            title: 'Account Settings',
            subtitle: 'Email, password & linked accounts',
            onTap: () => context.pushNamed(RouteNames.settingsAccount),
          ),
        ],
      ),
    );
  }
}

// ── _ActivityStatsCard ─────────────────────────────────────────────────────────

class _ActivityStatsCard extends StatelessWidget {
  const _ActivityStatsCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(label: 'Days Active', value: '47'),
          _StatDivider(),
          _StatColumn(label: 'Streak', value: '12'),
          _StatDivider(),
          _StatColumn(label: 'Achievements', value: '8'),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.displaySmall.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: 36,
      width: 1,
      color: colors.border.withValues(alpha: 0.5),
    );
  }
}

// ── _SignOutButton ─────────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButtonMd),
          ),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sign out',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              backgroundColor: colors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          );
        },
        child: Text(
          'Sign Out',
          style: AppTextStyles.bodyLarge.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: colors.border.withValues(alpha: 0.5),
      ),
    );
  }
}


