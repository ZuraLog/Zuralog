/// ZuraLog — Nutrition Rules Screen.
///
/// Lets the user create, edit, and delete persistent AI context rules for
/// the nutrition feature. Rules teach the AI about dietary preferences,
/// allergies, and portion habits so it asks fewer clarifying questions
/// when parsing meals.
///
/// Each user may have up to 20 rules.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Maximum number of rules a user may create.
const _maxRules = 20;

/// Example rules shown in the empty state to guide new users.
const _exampleRules = [
  'I am lactose intolerant — never assume dairy unless I say so.',
  'My default rice portion is 1 cup cooked (~200 g).',
  'When I say "coffee" I mean black coffee with no sugar.',
];

// ── NutritionRulesScreen ────────────────────────────────────────────────────

/// Screen for managing nutrition rules — persistent AI context hints.
class NutritionRulesScreen extends ConsumerStatefulWidget {
  const NutritionRulesScreen({super.key});

  @override
  ConsumerState<NutritionRulesScreen> createState() =>
      _NutritionRulesScreenState();
}

class _NutritionRulesScreenState extends ConsumerState<NutritionRulesScreen> {
  /// Whether an async operation (create/update/delete) is in progress.
  bool _isBusy = false;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Opens a dialog to create a new rule.
  Future<void> _showAddRuleDialog() async {
    final text = await _showRuleEditor(context);
    if (text == null || text.trim().isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      await repo.createRule(text.trim());
      ref.invalidate(nutritionRulesProvider);
      if (mounted) ZToast.success(context, 'Rule added.');
    } catch (e) {
      if (mounted) ZToast.error(context, 'Could not add the rule.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Opens a dialog pre-filled with [rule] text for editing.
  Future<void> _showEditRuleDialog(NutritionRule rule) async {
    final text = await _showRuleEditor(context, initialText: rule.ruleText);
    if (text == null || text.trim().isEmpty || text.trim() == rule.ruleText) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      await repo.updateRule(rule.id, text.trim());
      ref.invalidate(nutritionRulesProvider);
      if (mounted) ZToast.success(context, 'Rule updated.');
    } catch (e) {
      if (mounted) ZToast.error(context, 'Could not update the rule.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Shows a confirmation dialog before deleting [rule].
  Future<void> _confirmDelete(NutritionRule rule) async {
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Delete this rule?',
      body: 'The AI will no longer apply this preference when parsing meals.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      await repo.deleteRule(rule.id);
      ref.invalidate(nutritionRulesProvider);
      if (mounted) ZToast.success(context, 'Rule deleted.');
    } catch (e) {
      if (mounted) ZToast.error(context, 'Could not delete the rule.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Rule Editor Dialog ───────────────────────────────────────────────────

  /// Shows a dialog with a text field for creating or editing a rule.
  /// Returns the entered text, or null if cancelled.
  static Future<String?> _showRuleEditor(
    BuildContext context, {
    String? initialText,
  }) {
    final controller = TextEditingController(text: initialText);
    final colors = AppColorsOf(context);

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: colors.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.shapeXl),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  initialText != null ? 'Edit rule' : 'Add a rule',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Tell the AI about a dietary preference, allergy, or '
                  'portion habit so it makes better guesses.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TextField(
                  controller: controller,
                  maxLength: 500,
                  maxLines: 4,
                  minLines: 2,
                  autofocus: true,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. I always use olive oil when cooking',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.shapeMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppDimens.spaceMd),
                    counterStyle: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: ZButton(
                        label: 'Cancel',
                        variant: ZButtonVariant.secondary,
                        size: ZButtonSize.medium,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: ZButton(
                        label: 'Save',
                        size: ZButtonSize.medium,
                        onPressed: () {
                          final text = controller.text.trim();
                          Navigator.of(dialogContext).pop(text);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final rulesAsync = ref.watch(nutritionRulesProvider);
    const catColor = AppColors.categoryNutrition;

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Nutrition Rules',
        showProfileAvatar: false,
        subtitle: rulesAsync.whenOrNull(
          data: (rules) => '${rules.length} of $_maxRules rules',
        ),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ZErrorState(
          message: 'Something went wrong loading your rules.',
          onRetry: () => ref.invalidate(nutritionRulesProvider),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZEmptyState(
                      icon: Icons.rule_outlined,
                      title: 'No rules yet',
                      message: 'Rules help the AI understand your '
                          'preferences so it asks fewer questions.',
                      actionLabel: 'Add a rule',
                      onAction: _isBusy ? null : _showAddRuleDialog,
                    ),

                    const SizedBox(height: AppDimens.spaceLg),

                    // ── Example rules ─────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Example rules',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    for (final example in _exampleRules) ...[
                      ZuralogCard(
                        variant: ZCardVariant.plain,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: AppDimens.iconSm,
                              color: catColor,
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            Expanded(
                              child: Text(
                                example,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                    ],
                  ],
                ),
              ),
            );
          }

          // ── Rules list ─────────────────────────────────────────────────
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                  ),
                  itemCount: rules.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.spaceSm),
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return ZFadeSlideIn(
                      delay: Duration(milliseconds: index * 60),
                      child: _RuleCard(
                        rule: rule,
                        onEdit: _isBusy
                            ? null
                            : () => _showEditRuleDialog(rule),
                        onDelete: _isBusy
                            ? null
                            : () => _confirmDelete(rule),
                      ),
                    );
                  },
                ),
              ),

              // ── Add rule button ──────────────────────────────────────────
              if (rules.length < _maxRules)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    0,
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                  ),
                  child: ZButton(
                    label: 'Add a rule',
                    icon: Icons.add_rounded,
                    onPressed: _isBusy ? null : _showAddRuleDialog,
                    isLoading: _isBusy,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── _RuleCard ───────────────────────────────────────────────────────────────

/// A single rule card showing the text with edit and delete actions.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    this.onEdit,
    this.onDelete,
  });

  final NutritionRule rule;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const catColor = AppColors.categoryNutrition;

    return ZuralogCard(
      variant: ZCardVariant.plain,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rule icon.
          Container(
            width: AppDimens.iconContainerSm,
            height: AppDimens.iconContainerSm,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.shapeXs),
            ),
            child: const Center(
              child: Icon(
                Icons.rule_outlined,
                size: AppDimens.iconSm,
                color: catColor,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),

          // Rule text.
          Expanded(
            child: Text(
              rule.ruleText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),

          // Action buttons.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: AppDimens.iconSm,
                  color: colors.textSecondary,
                ),
                tooltip: 'Edit rule',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: AppDimens.iconSm,
                  color: colors.error,
                ),
                tooltip: 'Delete rule',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
