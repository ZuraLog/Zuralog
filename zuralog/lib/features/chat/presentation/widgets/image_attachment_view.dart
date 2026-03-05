/// Zuralog Edge Agent — Image Attachment View.
///
/// Renders an image attachment inside a message bubble as a tappable
/// thumbnail with rounded corners. Displays a loading shimmer while
/// the image loads from its signed URL.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';

/// Renders an image attachment as a constrained thumbnail.
///
/// Shows the local file if available, otherwise loads from [signedUrl].
class ImageAttachmentView extends StatelessWidget {
  /// The image attachment to display.
  final ChatAttachment attachment;

  /// Creates an [ImageAttachmentView].
  const ImageAttachmentView({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 240,
          maxHeight: 240,
        ),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    // Prefer local file for pending/uploading attachments.
    if (attachment.localPath != null) {
      return Image.file(
        File(attachment.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    // Fall back to signed URL.
    if (attachment.signedUrl != null && attachment.signedUrl!.isNotEmpty) {
      return Image.network(
        attachment.signedUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _loadingPlaceholder();
        },
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 120,
      height: 80,
      color: AppColors.textSecondary.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      width: 120,
      height: 80,
      color: AppColors.textSecondary.withValues(alpha: 0.08),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
