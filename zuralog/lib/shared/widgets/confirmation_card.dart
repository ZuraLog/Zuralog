/// Zuralog — ConfirmationCard widget.
///
/// In-chat card that presents parsed health data for user confirmation before
/// writing to the backend. Used for:
/// - NL logging confirmation (parsed entries → QuickLog)
/// - Memory extraction confirmation (extracted health facts → Pinecone)
/// - Food photo response (nutrition estimate → confirm/adjust)
///
/// ## Design spec
/// - Surface: `cardBackground` with `borderRadius: 20`
/// - Data preview: labeled rows with value on the right
/// - Primary action: "Confirm" — FilledButton, sage-green
/// - Secondary action: "Edit" — OutlinedButton
/// - Header: bold title + optional subtitle
///
/// ## Usage
/// ```dart
/// ConfirmationCard(
///   title: 'Log these entries?',
///   items: [
///     ConfirmationItem(label: 'Water', value: '500 ml'),
///     ConfirmationItem(label: 'Mood', value: '7/10'),
///   ],
///   onConfirm: () { /* write to backend */ },
///   onEdit: () { /* open edit sheet */ },
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/theme.dart';

// ── ConfirmationItem ──────────────────────────────────────────────────────────

/// A single label/value row in a [ConfirmationCard].
class ConfirmationItem {
  /// Creates a [ConfirmationItem].
  const ConfirmationItem({required this.label, required this.value});

  /// Human-readable label (e.g. 'Water', 'Mood').
  final String label;

  /// Human-readable value (e.g. '500 ml', '7/10').
  final String value;
}

// ── ConfirmationCard ──────────────────────────────────────────────────────────

/// Confirmation card rendered inside a chat thread.
class ConfirmationCard extends StatelessWidget {
  /// Creates a [ConfirmationCard].
  const ConfirmationCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onConfirm,
    this.onEdit,
    this.confirmLabel = 'Confirm',
    this.editLabel = 'Edit',
    this.isLoading = false,
  });

  /// Card title (e.g. "Log these entries?").
  final String title;

  /// Optional subtitle shown below the title.
  final String? subtitle;

  /// Data rows to display in the preview.
  final List<ConfirmationItem> items;

  /// Called when the user confirms the data.
  final VoidCallback onConfirm;

  /// Called when the user wants to edit the data. If `null`, edit button hidden.
  final VoidCallback? onEdit;

  /// Label for the confirm button. Default: "Confirm".
  final String confirmLabel;

  /// Label for the edit button. Default: "Edit".
  final String editLabel;

  /// When `true` shows a loading indicator on the confirm button.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bg = colors.cardBackground;
    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final divider = colors.border;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(color: textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style:
                        AppTextStyles.caption.copyWith(color: textSecondary),
                  ),
                ],
              ],
            ),
          ),

          // Divider
          Divider(color: divider, thickness: 0.5, height: 1),

          // Data rows
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _DataRow(
                    item: items[i],
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  if (i < items.length - 1) const SizedBox(height: 4),
                ],
              ],
            ),
          ),

          // Divider
          Divider(color: divider, thickness: 0.5, height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                if (onEdit != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onEdit,
                      child: Text(editLabel),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.textOnSage,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textOnSage,
                            ),
                          )
                        : Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DataRow ──────────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.item,
    required this.textPrimary,
    required this.textSecondary,
  });

  final ConfirmationItem item;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.label,
            style: AppTextStyles.body.copyWith(color: textSecondary),
          ),
        ),
        Text(
          item.value,
          style: AppTextStyles.body.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
