/// Zuralog Edge Agent — Attachment Repository.
///
/// Handles uploading file attachments to the Cloud Brain backend,
/// which stores them in Supabase Storage and returns metadata.
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';

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

    final type = _isAudioExtension(ext) ? AttachmentType.audio : AttachmentType.image;

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

  /// Returns `true` if the file extension is an audio format.
  bool _isAudioExtension(String ext) {
    return const {'m4a', 'wav', 'mp3', 'webm', 'aac'}.contains(ext);
  }
}
