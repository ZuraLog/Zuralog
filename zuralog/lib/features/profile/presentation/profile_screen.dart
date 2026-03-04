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
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';

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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar with gear icon ──────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_rounded,
                  color: AppColors.textPrimaryDark,
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
                style:
                    AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
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
              child: _EmergencyCardBanner(),
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
    final profile = ref.watch(_profileStateProvider);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
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
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundDark,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: AppColors.textSecondaryDark,
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
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textPrimaryDark,
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
              color: AppColors.textSecondary,
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
                style: AppTextStyles.caption.copyWith(
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceSm,
              ),
              filled: true,
              fillColor: AppColors.inputBackgroundDark,
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

  Color get _color {
    switch (tier) {
      case 'Pro':
        return AppColors.primary;
      case 'Premium':
        return AppColors.categoryMobility;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: _color),
          const SizedBox(width: 3),
          Text(
            tier,
            style: AppTextStyles.caption.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _EmergencyCardBanner ───────────────────────────────────────────────────────

class _EmergencyCardBanner extends StatefulWidget {
  @override
  State<_EmergencyCardBanner> createState() => _EmergencyCardBannerState();
}

class _EmergencyCardBannerState extends State<_EmergencyCardBanner> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.pushNamed(RouteNames.emergencyCard);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.categoryHeart.withValues(alpha: 0.18)
              : AppColors.categoryHeart.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border:
              Border.all(color: AppColors.categoryHeart.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.categoryHeart.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(
                Icons.medical_information_rounded,
                size: 24,
                color: AppColors.categoryHeart,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Health Card',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Blood type, allergies, medications & emergency contacts',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          _TapRow(
            icon: Icons.settings_rounded,
            iconColor: AppColors.textSecondary,
            title: 'Settings',
            subtitle: 'Notifications, appearance, coach & more',
            onTap: () => context.pushNamed(RouteNames.settings),
          ),
          const _Divider(),
          _TapRow(
            icon: Icons.workspace_premium_rounded,
            iconColor: AppColors.categoryMobility,
            title: 'Subscription',
            subtitle: '$tier plan',
            onTap: () => context.pushNamed(RouteNames.settingsSubscription),
          ),
          const _Divider(),
          _TapRow(
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
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
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
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
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
    return Container(
      height: 36,
      width: 1,
      color: AppColors.borderDark.withValues(alpha: 0.5),
    );
  }
}

// ── _SignOutButton ─────────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentDark,
          side: BorderSide(color: AppColors.accentDark.withValues(alpha: 0.5)),
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
                  color: AppColors.textPrimaryDark,
                ),
              ),
              backgroundColor: AppColors.surfaceDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          );
        },
        child: Text(
          'Sign Out',
          style: AppTextStyles.body.copyWith(
            color: AppColors.accentDark,
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
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: AppColors.borderDark.withValues(alpha: 0.5),
      ),
    );
  }
}

class _TapRow extends StatefulWidget {
  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  State<_TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<_TapRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.borderDark.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(widget.icon, size: 20, color: widget.iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
