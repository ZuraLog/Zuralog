/// Coach Tab — User Message Bubble.
///
/// Right-aligned bubble with a long-press context menu for Copy / Edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Single user message bubble with long-press actions.
///
/// [onEdit] is called when the user selects "Edit" — the caller should
/// pre-fill the input field and call [CoachChatNotifier.startEditing].
class CoachUserMessage extends StatelessWidget {
  const CoachUserMessage({
    super.key,
    required this.content,
    required this.onEdit,
    this.attachmentUrls = const [],
  });

  final String content;
  final VoidCallback onEdit;
  final List<String> attachmentUrls;

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colors = AppColorsOf(sheetCtx);
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceOverlay,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.shapeXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppDimens.spaceSm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: colors.primary),
                title: Text('Copy', style: AppTextStyles.bodyMedium),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  Navigator.pop(sheetCtx);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: colors.primary),
                title: Text('Edit', style: AppTextStyles.bodyMedium),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onEdit();
                },
              ),
              SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom + AppDimens.spaceSm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimens.spaceXl,
        bottom: AppDimens.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showContextMenu(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (attachmentUrls.isNotEmpty) ...[
                      Wrap(
                        spacing: AppDimens.spaceXs,
                        runSpacing: AppDimens.spaceXs,
                        children: attachmentUrls
                            .map(
                              (url) => ClipRRect(
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                child: Image.network(
                                  url,
                                  width: 120,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                    ],
                    Text(
                      content,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
