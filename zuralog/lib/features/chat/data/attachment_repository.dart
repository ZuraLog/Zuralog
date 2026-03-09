/// Zuralog Edge Agent — Attachment Repository.
///
/// Handles uploading file attachments to the Cloud Brain backend,
/// which stores them in Supabase Storage and returns metadata.
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';

// ── Domain types (previously in features/chat/domain/attachment.dart) ─────────

/// The media category of an uploaded attachment.
enum AttachmentType { image, pdf, document }

/// The upload lifecycle state of an attachment.
enum AttachmentStatus { pending, uploading, uploaded, error }

/// Metadata returned by the backend after a successful upload.
class ChatAttachment {
  final String id;
  final AttachmentType type;
  final String filename;
  final String localPath;
  final String? storagePath;
  final String? signedUrl;
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
    'size_bytes': sizeBytes,
    'mime_type': mimeType,
    'status': status.name,
  };
}

/// Repository for uploading chat attachments to the backend.
///
/// Uses [ApiClient] (Dio) for multipart file uploads to the
/// `/api/v1/chat/attachments` endpoint.
class AttachmentRepository {
  /// The REST API client for upload requests.
  final ApiClient _apiClient;

  /// Creates a new [AttachmentRepository].
  ///
  /// [apiClient] handles authenticated HTTP requests.
  AttachmentRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Uploads a local file to the backend storage.
  ///
  /// [filePath] is the absolute path to the local file.
  ///
  /// Returns a [ChatAttachment] populated with server-side metadata
  /// (storage path, signed URL, size, MIME type).
  ///
  /// Throws on network or validation errors.
  Future<ChatAttachment> uploadAttachment(String filePath) async {
    final file = File(filePath);
    final filename = file.uri.pathSegments.last;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';

    final AttachmentType type;
    if (const {'pdf'}.contains(ext)) {
      type = AttachmentType.pdf;
    } else if (const {'doc', 'docx', 'txt', 'rtf'}.contains(ext)) {
      type = AttachmentType.document;
    } else {
      type = AttachmentType.image;
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final response = await _apiClient.post(
      '/api/v1/chat/attachments',
      data: formData,
    );

    final data = response.data as Map<String, Object?>;

    return ChatAttachment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      filename: data['filename'] as String? ?? filename,
      localPath: filePath,
      storagePath: data['storage_path'] as String?,
      signedUrl: data['signed_url'] as String?,
      sizeBytes: data['size_bytes'] as int?,
      mimeType: data['mime_type'] as String?,
      status: AttachmentStatus.uploaded,
    );
  }

}
