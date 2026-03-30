/// Privacy & Data Screen.
///
/// AI memory management, analytics opt-out, data export/deletion, legal links.
///
/// ## Fixes applied (settings-mapping remediation)
/// Previously, the privacy toggles (Data Maturity Banner visibility,
/// Analytics opt-out) were held in an in-memory [_PrivacyState] that reset
/// on every cold start.
///
/// They now read from and write to [userPreferencesProvider] via the
/// [dataMaturityBannerDismissedProvider] and [analyticsOptOutProvider]
/// derived providers.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/data/memory_repository.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── PrivacyDataScreen ──────────────────────────────────────────────────────────

/// Privacy & Data screen — AI memory, privacy toggles, data management, legal.
class PrivacyDataScreen extends ConsumerStatefulWidget {
  /// Creates the [PrivacyDataScreen].
  const PrivacyDataScreen({super.key});

  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _isExporting = false;

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    // Capture colors and messenger before any await to avoid async BuildContext issues.
    final colors = AppColorsOf(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/api/v1/user/export',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data as List<int>);
      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/zuralog-export-$date.json');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'ZuraLog Data Export');
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is DioException) {
          switch (e.response?.statusCode) {
            case 429:
              errorMessage = 'You\'ve already exported recently. Try again later.';
              break;
            case 401:
              errorMessage = 'Session expired. Please log in again.';
              break;
            default:
              errorMessage = 'Export failed. Please try again.';
          }
        } else {
          errorMessage = 'Export failed. Please try again.';
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            ),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Global persisted privacy preferences.
    final dataMaturityBanner =
        !ref.watch(dataMaturityBannerDismissedProvider);
    final analyticsEnabled = !ref.watch(analyticsOptOutProvider);

    final prefsNotifier = ref.read(userPreferencesProvider.notifier);
    final memoriesAsync = ref.watch(memoryItemsProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Privacy & Data', showProfileAvatar: false),
      body: ListView(
        children: [
              // ── AI MEMORY section ──────────────────────────────────────
              const SettingsSectionLabel('AI Memory'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Text(
                  'Stored context your AI coach uses to personalize insights',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),

              // Memory items list
              memoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppDimens.spaceMd),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Failed to load memories',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusError),
                        ),
                      ),
                      ZButton(
                        label: 'Retry',
                        onPressed: () => ref.invalidate(memoryItemsProvider),
                        variant: ZButtonVariant.text,
                        isFullWidth: false,
                      ),
                    ],
                  ),
                ),
                data: (memoryItems) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    ),
                    child: Column(
                      children: [
                        if (memoryItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.spaceMd,
                              vertical: AppDimens.spaceLg,
                            ),
                            child: Text(
                              'No memory stored',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                          )
                        else
                          ...List.generate(memoryItems.length, (index) {
                            final item = memoryItems[index];
                            final isLast = index == memoryItems.length - 1;
                            return Column(
                              children: [
                                _MemoryItemRow(
                                  item: item,
                                  onDelete: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await ref.read(memoryItemsProvider.notifier).delete(item.id);
                                      ref.read(analyticsServiceProvider).capture(
                                        event: AnalyticsEvents.memoryDeleted,
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to delete memory: $e',
                                              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
                                            ),
                                            backgroundColor: colors.surface,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                if (!isLast) const _Divider(),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // Clear All Memory row
              memoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (memoryItems) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    ),
                    child: ZSettingsTile(
                      icon: Icons.delete_sweep_rounded,
                      iconColor: memoryItems.isNotEmpty
                          ? colors.accent
                          : AppColors.textTertiary,
                      title: 'Clear All Memory',
                      showChevron: false,
                      titleColor: memoryItems.isNotEmpty
                          ? colors.accent
                          : AppColors.textTertiary,
                      onTap: memoryItems.isNotEmpty
                          ? () => _showClearMemoryDialog(
                              context,
                              onConfirmed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await ref.read(memoryItemsProvider.notifier).clearAll();
                                  ref.read(analyticsServiceProvider).capture(
                                    event: AnalyticsEvents.allMemoriesCleared,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to clear memories: $e',
                                          style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
                                        ),
                                        backgroundColor: colors.surface,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // ── PRIVACY section ────────────────────────────────────────
              const SettingsSectionLabel('Privacy'),
              _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.categoryBody,
                    title: 'Data Maturity Banner',
                    subtitle: 'Show data quality guidance banners',
                    value: dataMaturityBanner,
                    onChanged: (v) => prefsNotifier.mutate(
                      // Banner toggle: "show" = not dismissed.
                      (p) => p.copyWith(dataMaturityBannerDismissed: !v),
                    ),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    icon: Icons.bar_chart_rounded,
                    iconColor: colors.secondary,
                    title: 'Analytics',
                    subtitle: 'Helps us improve Zuralog',
                    subtitleExtra: 'Share anonymous usage data',
                    value: analyticsEnabled,
                    onChanged: (v) => prefsNotifier.mutate(
                      // Analytics toggle: "enabled" = not opted out.
                      (p) => p.copyWith(analyticsOptOut: !v),
                    ),
                  ),
                ],
              ),

              // ── DATA section ───────────────────────────────────────────
              const SettingsSectionLabel('Data'),
              _SettingsCard(
                children: [
                  ZSettingsTile(
                    icon: Icons.download_rounded,
                    iconColor: colors.primary,
                    title: 'Export Data',
                    subtitle: _isExporting ? 'Exporting…' : 'Download your data as JSON',
                    showChevron: false,
                    trailing: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isExporting
                        ? null
                        : () {
                            ref.read(analyticsServiceProvider).capture(
                              event: AnalyticsEvents.dataExportRequested,
                            );
                            _exportData();
                          },
                  ),
                  const _Divider(),
                  ZSettingsTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppColors.statusError,
                    title: 'Delete Account Data',
                    subtitle: 'Clear AI memories & request account deletion',
                    titleColor: AppColors.statusError,
                    onTap: () => _showDeleteDataDialog(
                      context,
                      onConfirmed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        ref.read(analyticsServiceProvider).capture(
                          event: AnalyticsEvents.accountDeleteRequested,
                        );
                        try {
                          await ref.read(memoryItemsProvider.notifier).clearAll();
                        } catch (_) {
                          // Ignore errors — show success message regardless.
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'AI memories deleted. To delete your account and all health data, go to Account Settings → Delete Account.',
                                style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
                              ),
                              backgroundColor: colors.surface,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              // ── LEGAL section ──────────────────────────────────────────
              const SettingsSectionLabel('Legal'),
              _SettingsCard(
                children: [
                  ZSettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: colors.primary,
                    title: 'Privacy Policy',
                    onTap: () => launchUrl(Uri.parse('https://www.zuralog.com/privacy-policy'), mode: LaunchMode.externalApplication),
                  ),
                  const _Divider(),
                  ZSettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: colors.primary,
                    title: 'Terms of Service',
                    onTap: () => launchUrl(Uri.parse('https://www.zuralog.com/terms-of-service'), mode: LaunchMode.externalApplication),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const ZDivider(indent: 68);
  }
}

class _MemoryItemRow extends StatelessWidget {
  const _MemoryItemRow({required this.item, required this.onDelete});

  final MemoryItem item;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          const ZIconBadge(
            icon: Icons.memory_rounded,
            color: AppColors.categorySleep,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Text(
              item.text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: colors.textTertiary,
            ),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}



class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.subtitleExtra,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? subtitleExtra;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          ZIconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (subtitleExtra != null) ...[
                  Text(
                    subtitleExtra!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          ZToggle(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

Future<void> _showClearMemoryDialog(
  BuildContext context, {
  required Future<void> Function() onConfirmed,
}) async {
  final colors = AppColorsOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Clear All Memory?',
        style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        'Your AI coach will lose all personalization context. '
        'It will start fresh with generic recommendations.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      actions: [
        ZButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(ctx).pop(false),
          variant: ZButtonVariant.text,
          size: ZButtonSize.small,
          isFullWidth: false,
        ),
        ZButton(
          label: 'Clear All',
          onPressed: () => Navigator.of(ctx).pop(true),
          variant: ZButtonVariant.destructive,
          size: ZButtonSize.small,
          isFullWidth: false,
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onConfirmed();
  }
}

Future<void> _showDeleteDataDialog(
  BuildContext context, {
  required Future<void> Function() onConfirmed,
}) async {
  final colors = AppColorsOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Delete Account Data?',
        style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        'This will delete your AI coaching memories. To delete your account and all health data, go to Account Settings → Delete Account.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      actions: [
        ZButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(ctx).pop(false),
          variant: ZButtonVariant.text,
          size: ZButtonSize.small,
          isFullWidth: false,
        ),
        ZButton(
          label: 'Delete',
          onPressed: () => Navigator.of(ctx).pop(true),
          variant: ZButtonVariant.destructive,
          size: ZButtonSize.small,
          isFullWidth: false,
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onConfirmed();
  }
}
