/// Zuralog Edge Agent — Chat Attachment Domain Model.
///
/// Represents a file attachment (image or voice note) associated with
/// a chat message. Tracks upload lifecycle from local selection through
/// server-side storage.
library;

/// The type of file attachment.
enum AttachmentType {
  /// An image from the camera or photo library.
  image,

  /// A recorded voice note.
  audio,
}

/// Upload lifecycle state for an attachment.
enum AttachmentStatus {
  /// Selected locally, not yet uploaded.
  pending,

  /// Upload in progress.
  uploading,

  /// Successfully uploaded to storage.
  uploaded,

  /// Upload failed.
  failed,
}

/// A file attachment on a chat message.
///
/// Created locally when the user picks a file, updated as the upload
/// progresses, and finally populated with server-side metadata once
/// the upload completes.
class ChatAttachment {
  /// Unique local identifier for tracking this attachment.
  final String id;

  /// Whether this is an image or audio file.
  final AttachmentType type;

  /// The original filename.
  final String filename;

  /// Local file path on the device (for pending/uploading state).
  final String? localPath;

  /// Server-side storage path (e.g., 'chat-attachments/user-id/uuid/file.jpg').
  final String? storagePath;

  /// Time-limited signed URL for downloading/displaying.
  final String? signedUrl;

  /// File size in bytes.
  final int? sizeBytes;

  /// MIME type (e.g., 'image/jpeg', 'audio/m4a').
  final String? mimeType;

  /// Duration in seconds (audio only).
  final int? durationSeconds;

  /// Current upload status.
  final AttachmentStatus status;

  /// Creates a [ChatAttachment].
  const ChatAttachment({
    required this.id,
    required this.type,
    required this.filename,
    this.localPath,
    this.storagePath,
    this.signedUrl,
    this.sizeBytes,
    this.mimeType,
    this.durationSeconds,
    this.status = AttachmentStatus.pending,
  });

  /// Creates a [ChatAttachment] from a JSON map (server response).
  ///
  /// [json] is the decoded attachment metadata from the server.
  factory ChatAttachment.fromJson(Map<String, Object?> json) {
    return ChatAttachment(
      id: json['id'] as String? ?? '',
      type: (json['type'] as String?) == 'audio'
          ? AttachmentType.audio
          : AttachmentType.image,
      filename: json['filename'] as String? ?? '',
      storagePath: json['storage_path'] as String?,
      signedUrl: json['signed_url'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      mimeType: json['mime_type'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      status: AttachmentStatus.uploaded,
    );
  }

  /// Converts this attachment to a JSON-serializable map.
  ///
  /// Returns metadata suitable for sending via WebSocket.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type == AttachmentType.audio ? 'audio' : 'image',
      'filename': filename,
      if (storagePath != null) 'storage_path': storagePath,
      if (signedUrl != null) 'signed_url': signedUrl,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }

  /// Returns a copy with the specified fields replaced.
  ChatAttachment copyWith({
    AttachmentStatus? status,
    String? storagePath,
    String? signedUrl,
    int? sizeBytes,
    String? mimeType,
  }) {
    return ChatAttachment(
      id: id,
      type: type,
      filename: filename,
      localPath: localPath,
      storagePath: storagePath ?? this.storagePath,
      signedUrl: signedUrl ?? this.signedUrl,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      durationSeconds: durationSeconds,
      status: status ?? this.status,
    );
  }
}
