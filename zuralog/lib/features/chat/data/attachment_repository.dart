/// Zuralog Edge Agent — Attachment Repository.
///
/// Handles uploading file attachments to the Cloud Brain backend,
/// which processes files in memory and returns metadata — no permanent
/// storage is performed.
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/chat/domain/attachment_types.dart';

/// Repository for uploading chat attachments to the backend.
///
/// Uses [ApiClient] (Dio) for multipart file uploads to the
/// `/api/v1/chat/{conversationId}/attachments` endpoint.
class AttachmentRepository {
  /// The REST API client for upload requests.
  final ApiClient _apiClient;

  /// Creates a new [AttachmentRepository].
  ///
  /// [apiClient] handles authenticated HTTP requests.
  AttachmentRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Uploads a local file to the backend for processing.
  ///
  /// [filePath] is the absolute path to the local file.
  /// [conversationId] is the UUID of the conversation that owns this
  /// attachment. The file is uploaded to
  /// `/api/v1/chat/{conversationId}/attachments`. A real server-assigned UUID
  /// must be provided — the backend has no pre-conversation upload route.
  ///
  /// Returns a [ChatAttachment] populated with server-side metadata
  /// (extracted text, health facts, size, MIME type).
  ///
  /// Throws on network or validation errors.
  Future<ChatAttachment> uploadAttachment(
    String filePath, {
    required String conversationId,
  }) async {
    final file = File(filePath);
    final filename = file.uri.pathSegments.last;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';

    final AttachmentType type;
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'tiff', 'tif', 'svg'}.contains(ext)) {
      type = AttachmentType.image;
    } else if (const {'pdf'}.contains(ext)) {
      type = AttachmentType.pdf;
    } else {
      type = AttachmentType.document;
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final response = await _apiClient.post(
      '/api/v1/chat/$conversationId/attachments',
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
