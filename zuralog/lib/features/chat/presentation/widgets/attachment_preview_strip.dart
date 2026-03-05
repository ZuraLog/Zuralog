/// Zuralog Edge Agent — Attachment Preview Strip.
///
/// A horizontal strip of thumbnail previews shown above the text field
/// when the user has queued attachments before sending. Each preview
/// has a dismiss button to remove it from the queue.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';

/// A horizontal strip of attachment thumbnails above the input bar.
///
/// [attachments] is the list of pending attachments to preview.
/// [onRemove] is called with the attachment index when the user
/// taps the dismiss button on a preview.
class AttachmentPreviewStrip extends StatelessWidget {
  /// The list of pending attachments to preview.
  final List<ChatAttachment> attachments;

  /// Called when the user removes an attachment at the given index.
  final void Function(int index) onRemove;

  /// Creates an [AttachmentPreviewStrip].
  const AttachmentPreviewStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimens.spaceSm),
        itemBuilder: (context, index) {
          final att = attachments[index];
          return _PreviewTile(
            attachment: att,
            onRemove: () => onRemove(index),
          );
        },
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.attachment,
    required this.onRemove,
  });

  final ChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: attachment.type == AttachmentType.image
              ? _imagePreview()
              : _audioPreview(),
        ),
        // Dismiss button
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePreview() {
    if (attachment.localPath != null) {
      return Image.file(
        File(attachment.localPath!),
        fit: BoxFit.cover,
        width: 68,
        height: 68,
      );
    }
    return const Center(
      child: Icon(Icons.image_rounded, color: AppColors.textSecondary),
    );
  }

  Widget _audioPreview() {
    return const Center(
      child: Icon(
        Icons.mic_rounded,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }
}
