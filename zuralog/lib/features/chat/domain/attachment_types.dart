/// Zuralog Edge Agent — Chat Attachment Domain Types.
///
/// Single canonical definition of all attachment-related types used across
/// both the data layer (AttachmentRepository) and the UI layer
/// (CoachAttachmentPanel, AttachmentPreviewBar, chat screens).
library;

import 'dart:io';

// ── AttachmentException ───────────────────────────────────────────────────────

/// Thrown by [AttachmentRepository] on validation or upload failures.
class AttachmentException implements Exception {
  final String message;
  const AttachmentException(this.message);
  @override
  String toString() => message;
}

// ── AttachmentType ─────────────────────────────────────────────────────────────

/// The media category of an attachment.
enum AttachmentType { image, pdf, document }

// ── AttachmentStatus ──────────────────────────────────────────────────────────

/// The upload lifecycle state of an attachment.
enum AttachmentStatus { pending, uploading, uploaded, error }

// ── ChatAttachment ────────────────────────────────────────────────────────────

/// Metadata returned by the backend after a successful upload.
class ChatAttachment {
  final String id;
  final AttachmentType type;
  final String filename;
  final String localPath;
  final String? storagePath;
  final String? signedUrl;

  /// Base64 `data:image/...;base64,...` URI returned by the backend for
  /// image uploads. Forwarded to the WebSocket so the vision LLM can see
  /// the image without needing external storage.
  final String? dataUrl;

  final int? sizeBytes;
  final String? mimeType;
  final AttachmentStatus status;

  const ChatAttachment({
    required this.id,
    required this.type,
    required this.filename,
    required this.localPath,
    this.storagePath,
    this.signedUrl,
    this.dataUrl,
    this.sizeBytes,
    this.mimeType,
    required this.status,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'filename': filename,
    'local_path': localPath,
    'storage_path': storagePath,
    'signed_url': signedUrl,
    'data_url': dataUrl,
    'size_bytes': sizeBytes,
    'mime_type': mimeType,
    'status': status.name,
  };
}

// ── PendingAttachment ─────────────────────────────────────────────────────────

/// Represents a pending attachment before upload.
class PendingAttachment {
  const PendingAttachment({
    required this.file,
    required this.type,
    required this.name,
  });

  final File file;
  final AttachmentType type;
  final String name;
}
