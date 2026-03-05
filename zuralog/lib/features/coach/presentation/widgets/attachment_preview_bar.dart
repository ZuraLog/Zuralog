/// Attachment preview bar for Coach chat input.
///
/// Displays a horizontal scroll of pending attachment thumbnails,
/// each with an ✕ remove button. Hidden when attachments list is empty.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'attachment_picker_sheet.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: attachment.type == AttachmentType.image
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(attachment.file, fit: BoxFit.cover),
                )
              : Icon(
                  attachment.type == AttachmentType.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                // 0xFF636366 == AppColors.textSecondaryLight (exact match).
                color: AppColors.textSecondaryLight,
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
      ],
    );
  }
}
