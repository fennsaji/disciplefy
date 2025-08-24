import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

/// Exception thrown when file upload fails
class FileUploadException implements Exception {
  final String message;
  final String? code;

  const FileUploadException(this.message, {this.code});

  @override
  String toString() => 'FileUploadException: $message';
}

/// Progress callback for file uploads
typedef UploadProgressCallback = void Function(double progress);

/// Result of a successful file upload
class UploadResult {
  final String fileName;
  final String fullPath;
  final String publicUrl;
  final int fileSizeBytes;
  final String mimeType;

  const UploadResult({
    required this.fileName,
    required this.fullPath,
    required this.publicUrl,
    required this.fileSizeBytes,
    required this.mimeType,
  });

  /// Get human-readable file size
  String get fileSizeFormatted => _formatFileSize(fileSizeBytes);

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Service for uploading files to Supabase Storage
/// Specialized for profile pictures with proper security and optimization
class FileUploadService {
  static const String _profilePicturesBucket = 'profile-pictures';
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Uuid _uuid = Uuid();

  final SupabaseClient _supabase;

  FileUploadService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Upload a profile picture for a specific user
  ///
  /// File will be stored in user-specific folder: {userId}/profile.{extension}
  /// Returns public URL for accessing the uploaded image
  Future<UploadResult> uploadProfilePicture({
    required String userId,
    required File imageFile,
    UploadProgressCallback? onProgress,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 [UPLOAD] Starting profile picture upload for user: $userId');
      }

      // Validate inputs
      await _validateUploadInputs(userId, imageFile);

      // Determine file extension and MIME type
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final extension = _getFileExtension(mimeType);

      // Generate file path: {userId}/profile.{extension}
      final fileName = 'profile.$extension';
      final filePath = '$userId/$fileName';

      if (kDebugMode) {
        print('📤 [UPLOAD] File path: $filePath');
        print('📤 [UPLOAD] MIME type: $mimeType');
      }

      // Upload with retry logic
      final uploadResult = await _uploadWithRetry(
        filePath: filePath,
        file: imageFile,
        mimeType: mimeType,
        onProgress: onProgress,
      );

      // Get public URL
      final publicUrl =
          _supabase.storage.from(_profilePicturesBucket).getPublicUrl(filePath);

      final fileSize = await imageFile.length();

      if (kDebugMode) {
        print('📤 [UPLOAD] Upload successful!');
        print('📤 [UPLOAD] Public URL: $publicUrl');
        print(
            '📤 [UPLOAD] File size: ${UploadResult._formatFileSize(fileSize)}');
      }

      return UploadResult(
        fileName: fileName,
        fullPath: filePath,
        publicUrl: publicUrl,
        fileSizeBytes: fileSize,
        mimeType: mimeType,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [UPLOAD] Upload failed: $e');
      }

      if (e is FileUploadException) {
        rethrow;
      }

      throw FileUploadException(
          'Failed to upload profile picture: ${e.toString()}');
    }
  }

  /// Delete a user's profile picture
  Future<void> deleteProfilePicture({required String userId}) async {
    try {
      if (kDebugMode) {
        print('🗑️ [UPLOAD] Deleting profile picture for user: $userId');
      }

      // List all files in user's folder
      final fileList = await _supabase.storage
          .from(_profilePicturesBucket)
          .list(path: userId);

      // Delete all profile pictures for this user
      for (final file in fileList) {
        if (file.name.startsWith('profile.')) {
          final filePath = '$userId/${file.name}';
          await _supabase.storage
              .from(_profilePicturesBucket)
              .remove([filePath]);

          if (kDebugMode) {
            print('🗑️ [UPLOAD] Deleted: $filePath');
          }
        }
      }

      if (kDebugMode) {
        print('🗑️ [UPLOAD] Profile picture deletion completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [UPLOAD] Delete failed: $e');
      }
      throw FileUploadException(
          'Failed to delete profile picture: ${e.toString()}');
    }
  }

  /// Check if user has an existing profile picture
  Future<String?> getExistingProfilePictureUrl(String userId) async {
    try {
      final fileList = await _supabase.storage
          .from(_profilePicturesBucket)
          .list(path: userId);

      // Find the most recent profile picture
      for (final file in fileList) {
        if (file.name.startsWith('profile.')) {
          final filePath = '$userId/${file.name}';
          return _supabase.storage
              .from(_profilePicturesBucket)
              .getPublicUrl(filePath);
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [UPLOAD] Failed to check existing profile picture: $e');
      }
      return null;
    }
  }

  /// Validate upload inputs
  Future<void> _validateUploadInputs(String userId, File imageFile) async {
    // Validate user ID
    if (userId.isEmpty) {
      throw const FileUploadException('User ID cannot be empty');
    }

    // Check if file exists
    if (!await imageFile.exists()) {
      throw const FileUploadException('Image file does not exist');
    }

    // Check file size (5MB limit)
    final fileSize = await imageFile.length();
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (fileSize > maxSize) {
      throw FileUploadException(
          'File too large. Maximum size: ${UploadResult._formatFileSize(maxSize)}');
    }

    if (fileSize == 0) {
      throw const FileUploadException('File is empty');
    }

    // Validate MIME type
    final mimeType = lookupMimeType(imageFile.path);
    if (mimeType == null || !_isValidImageMimeType(mimeType)) {
      throw const FileUploadException(
          'Invalid image format. Supported: JPEG, PNG, WebP');
    }
  }

  /// Check if MIME type is supported for profile pictures
  bool _isValidImageMimeType(String mimeType) {
    const supportedTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];
    return supportedTypes.contains(mimeType.toLowerCase());
  }

  /// Get appropriate file extension for MIME type
  String _getFileExtension(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  /// Upload with exponential backoff retry logic
  Future<String> _uploadWithRetry({
    required String filePath,
    required File file,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    int attempts = 0;
    Duration delay = _baseRetryDelay;

    while (attempts < _maxRetries) {
      try {
        if (kDebugMode && attempts > 0) {
          print('📤 [UPLOAD] Retry attempt $attempts for: $filePath');
        }

        final fileBytes = await file.readAsBytes();

        // Report progress
        onProgress?.call(0.1); // Starting upload

        final response =
            await _supabase.storage.from(_profilePicturesBucket).uploadBinary(
                  filePath,
                  fileBytes,
                  fileOptions: FileOptions(
                    contentType: mimeType,
                    cacheControl: '3600', // Cache for 1 hour
                    upsert: true, // Replace existing file
                  ),
                );

        // Report completion
        onProgress?.call(1.0);

        if (kDebugMode) {
          print('📤 [UPLOAD] Upload successful: $response');
        }

        return response;
      } catch (e) {
        attempts++;

        if (kDebugMode) {
          print('🚨 [UPLOAD] Attempt $attempts failed: $e');
        }

        // If this is the last attempt or error is not retryable, rethrow
        if (attempts >= _maxRetries || !_isRetryableError(e)) {
          throw FileUploadException(
            'Upload failed after $attempts attempts: ${e.toString()}',
            code: 'UPLOAD_FAILED',
          );
        }

        // Wait before retrying with exponential backoff + jitter
        final jitter = Random().nextDouble() * 0.5; // 0-50% jitter
        final actualDelay = Duration(
          milliseconds: (delay.inMilliseconds * (1 + jitter)).round(),
        );

        if (kDebugMode) {
          print(
              '📤 [UPLOAD] Waiting ${actualDelay.inSeconds}s before retry...');
        }

        await Future.delayed(actualDelay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).round());
      }
    }

    throw const FileUploadException('Upload retry logic error');
  }

  /// Check if an error is retryable
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network-related errors that can be retried
    const retryableErrors = [
      'network',
      'timeout',
      'connection',
      'socket',
      'dns',
      'unreachable',
      'temporary failure',
      'service unavailable',
      '502',
      '503',
      '504',
    ];

    for (final retryableError in retryableErrors) {
      if (errorString.contains(retryableError)) {
        return true;
      }
    }

    // Don't retry authentication errors, validation errors, etc.
    const nonRetryableErrors = [
      '401', // Unauthorized
      '403', // Forbidden
      '400', // Bad Request
      '404', // Not Found
      'invalid',
      'unauthorized',
      'forbidden',
    ];

    for (final nonRetryableError in nonRetryableErrors) {
      if (errorString.contains(nonRetryableError)) {
        return false;
      }
    }

    // Default to retryable for unknown errors
    return true;
  }

  /// Get upload progress simulation (for better UX)
  /// Since Supabase doesn't provide real-time progress, we simulate it
  Stream<double> simulateUploadProgress({
    required int fileSizeBytes,
    required Duration estimatedDuration,
  }) async* {
    const int steps = 20;
    final stepDuration = Duration(
      milliseconds: (estimatedDuration.inMilliseconds / steps).round(),
    );

    for (int i = 0; i <= steps; i++) {
      // Use exponential curve for more realistic progress
      final progress = _easeOutCubic(i / steps);
      yield progress;

      if (i < steps) {
        await Future.delayed(stepDuration);
      }
    }
  }

  /// Ease-out cubic animation curve for progress simulation
  double _easeOutCubic(double t) {
    final t1 = t - 1;
    return t1 * t1 * t1 + 1;
  }

  /// Clean up failed uploads (call periodically)
  static Future<void> cleanupFailedUploads() async {
    try {
      // This would require admin access to list all files
      // In practice, you'd implement this as a backend cron job
      if (kDebugMode) {
        print('🧹 [UPLOAD] Cleanup failed uploads (would need admin access)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [UPLOAD] Failed to cleanup uploads: $e');
      }
    }
  }

  /// Get storage usage for a user (if needed for quota management)
  Future<int> getUserStorageUsage(String userId) async {
    try {
      final fileList = await _supabase.storage
          .from(_profilePicturesBucket)
          .list(path: userId);

      int totalSize = 0;
      for (final file in fileList) {
        totalSize += (file.metadata?['size'] as num?)?.toInt() ?? 0;
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [UPLOAD] Failed to get storage usage: $e');
      }
      return 0;
    }
  }
}
