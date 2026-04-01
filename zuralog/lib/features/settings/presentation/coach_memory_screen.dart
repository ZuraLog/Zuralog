/// Coach Memory Screen — Long-term memory toggle, stored memory list,
/// and bulk clear action.
///
/// Reached via /settings/coach/memory (nested under CoachSettingsScreen).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/data/memory_repository.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Category helpers ──────────────────────────────────────────────────────────

Color _categoryColor(String? category) => switch (category) {
      'goal' => AppColors.categoryActivity,
      'injury' => AppColors.categoryHeart,
      'pr' => AppColors.categoryWellness,
      'preference' => AppColors.categoryBody,
      'program' => AppColors.categoryNutrition,
      _ => AppColors.categorySleep,
    };

IconData _categoryIcon(String? category) => switch (category) {
      'goal' => Icons.flag_rounded,
      'injury' => Icons.favorite_rounded,
      'pr' => Icons.emoji_events_rounded,
      'preference' => Icons.tune_rounded,
      'program' => Icons.calendar_today_rounded,
      _ => Icons.memory_rounded,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class CoachMemoryScreen extends ConsumerWidget {
  const CoachMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    final memoryEnabled = prefs?.memoryEnabled ?? true;
    final memoriesAsync = ref.watch(memoryItemsProvider);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Memory', showProfileAvatar: false),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
        children: [
          // ── LONG-TERM MEMORY section ───────────────────────────────────────
          const SettingsSectionLabel('Long-Term Memory'),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Text(
              'When on, your coach remembers your goals, injuries, and preferences across every conversation.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              child: ZSettingsTile(
                icon: Icons.psychology_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Long-Term Memory',
                subtitle: 'Remember goals and context across sessions',
                showChevron: false,
                trailing: ZToggle(
                  value: memoryEnabled,
                  onChanged: (v) => _toggleMemory(ref, v),
                ),
                onTap: () => _toggleMemory(ref, !memoryEnabled),
              ),
            ),
          ),

          // Warning banner — shown only when memory is off
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !memoryEnabled
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: const ZAlertBanner(
                      variant: ZAlertVariant.warning,
                      message:
                          'Memory is off. Your coach will start every conversation fresh with no personalization.',
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── STORED MEMORIES section ────────────────────────────────────────
          const SettingsSectionLabel('Stored Memories'),

          memoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppDimens.spaceMd),
              child: Center(child: ZCircularProgress()),
            ),
            error: (e, _) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Failed to load memories',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.statusError),
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
            data: (items) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: items.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusCard),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceLg,
                      ),
                      child: Text(
                        memoryEnabled
                            ? 'Nothing stored yet — keep chatting and your coach will start remembering things about you.'
                            : 'Turn on Long-Term Memory to start building context.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusCard),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _MemoryItemRow(
                              item: items[i],
                              onDelete: () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(memoryItemsProvider.notifier)
                                      .delete(items[i].id);
                                  ref
                                      .read(analyticsServiceProvider)
                                      .capture(
                                        event: AnalyticsEvents.memoryDeleted,
                                      );
                                } catch (_) {
                                  if (context.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to delete memory',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                  color: colors.textPrimary),
                                        ),
                                        backgroundColor: colors.surface,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppDimens.radiusSm,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            if (i < items.length - 1)
                              const ZDivider(indent: 68),
                          ],
                        ],
                      ),
                    ),
            ),
          ),

          // ── CLEAR ALL — only shown when memories exist ─────────────────────
          memoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusCard),
                      ),
                      child: ZSettingsTile(
                        icon: Icons.delete_sweep_rounded,
                        iconColor: AppColors.statusError,
                        title: 'Clear All Memories',
                        titleColor: AppColors.statusError,
                        showChevron: false,
                        onTap: () => _showClearDialog(context, ref),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
    );
  }

  void _toggleMemory(WidgetRef ref, bool newValue) {
    ref.read(userPreferencesProvider.notifier).mutate(
          (p) => p.copyWith(memoryEnabled: newValue),
        );
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.memoryToggled,
      properties: {'enabled': newValue},
    );
  }
}

// ── Memory item row ───────────────────────────────────────────────────────────

class _MemoryItemRow extends StatelessWidget {
  const _MemoryItemRow({required this.item, required this.onDelete});

  final MemoryItem item;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final category = item.metadata['category'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          ZIconBadge(
            icon: _categoryIcon(category),
            color: _categoryColor(category),
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

// ── Clear all dialog ──────────────────────────────────────────────────────────

Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
  final colors = AppColorsOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text(
        'Clear All Memories?',
        style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        'Your coach will lose all personalization context and start fresh with generic recommendations.',
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
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
    await ref.read(memoryItemsProvider.notifier).clearAll();
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.allMemoriesCleared,
    );
  }
}
