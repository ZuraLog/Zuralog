/// Zuralog Edge Agent — Attachment Repository.
///
/// Handles uploading file attachments to the Cloud Brain backend,
/// which processes files in memory and returns metadata — no permanent
/// storage is performed.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

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
  /// [onSendProgress] is an optional callback for upload progress.
  ///
  /// Returns a [ChatAttachment] populated with server-side metadata
  /// (extracted text, health facts, size, MIME type).
  ///
  /// Throws [AttachmentException] on validation or network errors.
  Future<ChatAttachment> uploadAttachment(
    String filePath, {
    required String conversationId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final file = File(filePath);
    final filename = file.uri.pathSegments.last;

    // Fix M7: file size check before upload.
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw AttachmentException(
        'File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB (max 10 MB)',
      );
    }

    // Fix H21: MIME type detection via magic bytes.
    final headerBytes = await file
        .openRead(0, 12)
        .fold<List<int>>([], (p, c) => p..addAll(c));
    final mimeType = lookupMimeType(filePath, headerBytes: headerBytes);
    final AttachmentType type;
    if (mimeType != null && mimeType.startsWith('image/')) {
      type = AttachmentType.image;
    } else if (mimeType == 'application/pdf') {
      type = AttachmentType.pdf;
    } else {
      type = AttachmentType.document;
    }

    // Fix C12/C13: wrap MultipartFile creation in try/catch.
    FormData formData;
    try {
      formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: DioMediaType.parse(mimeType ?? 'application/octet-stream'),
        ),
      });
    } on FileSystemException catch (e) {
      throw AttachmentException('File not found or inaccessible: ${e.message}');
    }

    final response = await _apiClient.post(
      '/api/v1/chat/$conversationId/attachments',
      data: formData,
      onSendProgress: onSendProgress,
    );

    // Fix C13: type-guarded cast on response.
    final rawData = response.data;
    if (rawData is! Map<String, Object?>) {
      throw const AttachmentException('Unexpected upload response');
    }
    final data = rawData;

    return ChatAttachment(
      // Fix C11: UUID for attachment ID.
      id: const Uuid().v4(),
      type: type,
      filename: data['filename'] as String? ?? filename,
      localPath: filePath,
      storagePath: data['storage_path'] as String?,
      signedUrl: data['signed_url'] as String?,
      // Fix M20: safe cast for sizeBytes.
      sizeBytes: (data['size_bytes'] as num?)?.toInt(),
      mimeType: data['mime_type'] as String?,
      status: AttachmentStatus.uploaded,
    );
  }
}
