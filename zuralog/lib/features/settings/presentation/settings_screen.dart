/// Zuralog Settings — Settings Screen.
///
/// Provides user profile display, appearance customisation, subscription
/// status, coach persona selection, data & privacy controls, and logout.
/// Structured as iOS-style grouped sections within a [CustomScrollView]
/// with a [SliverAppBar].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/presentation/widgets/theme_selector.dart';
import 'package:zuralog/features/settings/presentation/widgets/user_header.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/features/subscription/presentation/paywall_screen.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// The Settings screen for Zuralog.
///
/// Presents user identity at the top, followed by grouped sections for
/// Appearance, Subscription, Coach Persona, Data & Privacy, and a
/// full-width Logout button at the bottom.
///
/// This screen is pushed over the [AppShell] (not a tab), so the
/// [SliverAppBar] includes an automatic back button.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for [SettingsScreen].
///
/// Manages the selected Coach Persona pill index (decorative only).
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Index of the selected Coach Persona pill (0 = Motivator, 1 = Analyst,
  /// 2 = Friend). Decorative only — has no functional effect.
  int _selectedPersonaIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            title: const Text('Settings'),
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
              tooltip: 'Back',
            ),
          ),

          // ── User Header ──────────────────────────────────────────────────
          const SliverToBoxAdapter(child: UserHeader()),

          // ── Section divider ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionDivider(isDark: isDark),
          ),

          // ── Appearance Section ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SettingsSection(
              label: 'Appearance',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: const ThemeSelector(),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionDivider(isDark: isDark),
          ),

          // ── Subscription Section ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SettingsSection(
              label: 'Subscription',
              child: _SubscriptionRow(isPremium: isPremium),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionDivider(isDark: isDark),
          ),

          // ── Coach Persona Section ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SettingsSection(
              label: 'Coach Persona',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: _CoachPersonaSelector(
                  selectedIndex: _selectedPersonaIndex,
                  onSelected: (index) =>
                      setState(() => _selectedPersonaIndex = index),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionDivider(isDark: isDark),
          ),

          // ── Data & Privacy Section ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _SettingsSection(
              label: 'Data & Privacy',
              child: _DataPrivacyGroup(colorScheme: colorScheme),
            ),
          ),

          SliverToBoxAdapter(
            child: _SectionDivider(isDark: isDark),
          ),

          // ── Logout Button ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceXl,
              ),
              child: _LogoutButton(
                onLogout: () => _handleLogout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logs out the current user and navigates to the welcome screen.
  ///
  /// Calls [AuthStateNotifier.logout] to clear tokens and auth state,
  /// then uses [GoRouter] to replace the navigation stack with the
  /// welcome route.
  Future<void> _handleLogout(BuildContext context) async {
    await ref.read(authStateProvider.notifier).logout();
    if (!context.mounted) return;
    context.go(RouteNames.welcomePath);
  }
}

// ── Private Subwidgets ────────────────────────────────────────────────────────

/// A lightweight section container with a label above its content.
///
/// Renders a [SectionHeader] with [label] and the provided [child] below it.
class _SettingsSection extends StatelessWidget {
  /// The section heading label.
  final String label;

  /// The content widget displayed beneath the header.
  final Widget child;

  /// Creates a [_SettingsSection].
  const _SettingsSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: label),
          const SizedBox(height: AppDimens.spaceSm),
          child,
        ],
      ),
    );
  }
}

/// A subtle horizontal divider between settings sections.
class _SectionDivider extends StatelessWidget {
  /// Whether the current theme is dark (affects divider colour).
  final bool isDark;

  /// Creates a [_SectionDivider].
  const _SectionDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppDimens.spaceMd,
      endIndent: AppDimens.spaceMd,
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    );
  }
}

/// Subscription status row displayed inside the Subscription section.
///
/// Shows "Zuralog Premium ✓" in sage green when [isPremium] is `true`.
/// Shows "Free Plan" with an "Upgrade" button otherwise; tapping "Upgrade"
/// pushes [PaywallScreen] via [Navigator].
class _SubscriptionRow extends StatelessWidget {
  /// Whether the current user has a premium subscription.
  final bool isPremium;

  /// Creates a [_SubscriptionRow].
  const _SubscriptionRow({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Text(
          'Zuralog Premium ✓',
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Free Plan',
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PaywallScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

/// The persona options available for Coach Persona selection.
const List<String> _kPersonaLabels = ['Motivator', 'Analyst', 'Friend'];

/// Decorative segmented pill row for Coach Persona selection.
///
/// Presents three horizontal pill options: "Motivator", "Analyst", "Friend".
/// The [selectedIndex] pill is highlighted with [AppColors.primary] background.
/// No functional logic is attached — this is a visual placeholder.
class _CoachPersonaSelector extends StatelessWidget {
  /// The index of the currently selected persona (0, 1, or 2).
  final int selectedIndex;

  /// Callback invoked when a persona pill is tapped.
  ///
  /// Receives the tapped pill's index as its argument.
  final ValueChanged<int> onSelected;

  /// Creates a [_CoachPersonaSelector].
  const _CoachPersonaSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      height: AppDimens.touchTargetMin,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: List.generate(
          _kPersonaLabels.length,
          (index) => _PersonaPill(
            label: _kPersonaLabels[index],
            isSelected: index == selectedIndex,
            onTap: () => onSelected(index),
          ),
        ),
      ),
    );
  }
}

/// A single pill option within [_CoachPersonaSelector].
class _PersonaPill extends StatelessWidget {
  /// The persona label text.
  final String label;

  /// Whether this pill is currently selected.
  final bool isSelected;

  /// Callback invoked when this pill is tapped.
  final VoidCallback onTap;

  /// Creates a [_PersonaPill].
  const _PersonaPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(AppDimens.spaceXs),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppColors.primaryButtonText
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Data & Privacy section's list tile group.
///
/// Contains three entries:
/// - "Export My Data" — shows a "coming soon" SnackBar.
/// - "Delete Account" — shows a confirmation dialog with destructive action.
/// - "Privacy Policy" — opens [_kPrivacyPolicyUrl] via [url_launcher].
class _DataPrivacyGroup extends StatelessWidget {
  /// The active [ColorScheme] used for styling.
  final ColorScheme colorScheme;

  /// Creates a [_DataPrivacyGroup].
  const _DataPrivacyGroup({required this.colorScheme});

  /// The stub URL for the privacy policy page.
  static const String _kPrivacyPolicyUrl = 'https://zuralog.com/privacy';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Export My Data
        ListTile(
          dense: true,
          title: Text(
            'Export My Data',
            style: AppTextStyles.body.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export coming soon')),
            );
          },
        ),

        // Delete Account
        ListTile(
          dense: true,
          title: Text(
            'Delete Account',
            style: AppTextStyles.body.copyWith(
              color: colorScheme.error,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.error,
          ),
          onTap: () => _showDeleteAccountDialog(context),
        ),

        // Privacy Policy
        ListTile(
          dense: true,
          title: Text(
            'Privacy Policy',
            style: AppTextStyles.body.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          trailing: Icon(
            Icons.open_in_new_rounded,
            color: colorScheme.onSurfaceVariant,
            size: AppDimens.iconSm,
          ),
          onTap: () => _launchPrivacyPolicy(context),
        ),
      ],
    );
  }

  /// Shows a confirmation dialog before deleting the account.
  ///
  /// The dialog presents a destructive "Delete" action and a safe "Cancel"
  /// action. No actual deletion occurs — this is a placeholder.
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This will permanently delete your account and all associated '
            'data. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Launches the privacy policy URL using [url_launcher].
  ///
  /// Shows a SnackBar if the URL cannot be opened.
  Future<void> _launchPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(_kPrivacyPolicyUrl);
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Privacy Policy')),
      );
    }
  }
}

/// Full-width logout button with destructive (red) styling.
///
/// Renders an [OutlinedButton] with a red border and red label text.
/// Tapping invokes [onLogout].
class _LogoutButton extends StatelessWidget {
  /// Callback invoked when the logout button is tapped.
  final VoidCallback onLogout;

  /// Creates a [_LogoutButton].
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.accentDark
        : AppColors.accentLight;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor),
          minimumSize: const Size(double.infinity, AppDimens.touchTargetMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
        child: Text(
          'Log Out',
          style: AppTextStyles.body.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
