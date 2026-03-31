/// Attachment preview bar for Coach chat input.
///
/// Displays a horizontal scroll of pending attachment thumbnails,
/// each with an ✕ remove button. Hidden when attachments list is empty.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/chat/domain/attachment_types.dart';

// ── AttachmentPreviewBar ──────────────────────────────────────────────────────

/// Horizontal scrollable row of [PendingAttachment] preview tiles.
///
/// Returns [SizedBox.shrink] when [attachments] is empty so it takes no space.
class AttachmentPreviewBar extends StatelessWidget {
  const AttachmentPreviewBar({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<PendingAttachment> attachments;

  /// Called with the index of the attachment to remove.
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd, vertical: AppDimens.spaceSm),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimens.spaceSm),
        itemBuilder: (_, i) => _PreviewTile(
          attachment: attachments[i],
          onRemove: () => onRemove(i),
        ),
      ),
    );
  }
}

// ── _PreviewTile ──────────────────────────────────────────────────────────────

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.attachment, required this.onRemove});

  final PendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: attachment.type == AttachmentType.image
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  // Fix M17: image error builder.
                  child: Image.file(
                    attachment.file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image_outlined, size: 28),
                  ),
                )
              : Icon(
                  attachment.type == AttachmentType.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_rounded,
                  color: colors.primary,
                  size: 28,
                ),
        ),
        // Fix M42: larger remove button hit target (44x44 dp).
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
