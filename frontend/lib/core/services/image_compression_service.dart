import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Exception thrown when image compression fails
class ImageCompressionException implements Exception {
  final String message;
  const ImageCompressionException(this.message);

  @override
  String toString() => 'ImageCompressionException: $message';
}

/// Result of image compression containing compressed file and metadata
class CompressionResult {
  final File compressedFile;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double compressionRatio;
  final int width;
  final int height;

  const CompressionResult({
    required this.compressedFile,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.compressionRatio,
    required this.width,
    required this.height,
  });

  /// Get compression percentage (e.g., 0.75 = 75% compression)
  double get compressionPercentage => compressionRatio;

  /// Get file size reduction in bytes
  int get sizeSavings => originalSizeBytes - compressedSizeBytes;

  /// Get human-readable file sizes
  String get originalSizeFormatted => _formatFileSize(originalSizeBytes);
  String get compressedSizeFormatted => _formatFileSize(compressedSizeBytes);

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Service for compressing and optimizing profile pictures
/// Handles both mobile and web platforms with different compression strategies
class ImageCompressionService {
  static const int _targetMaxWidth = 512;
  static const int _targetMaxHeight = 512;
  static const int _targetFileSizeBytes = 200 * 1024; // 200KB
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _defaultQuality = 85;
  static const Uuid _uuid = Uuid();

  /// Compress an image file to meet profile picture requirements
  ///
  /// Requirements:
  /// - Max dimensions: 512x512 pixels
  /// - Target file size: < 200KB
  /// - Supported formats: JPEG, PNG, WebP
  /// - Quality: 85% (adjustable based on file size)
  Future<CompressionResult> compressProfilePicture(File imageFile) async {
    try {
      // Validate input file
      await _validateInputFile(imageFile);

      final originalSize = await imageFile.length();

      if (kDebugMode) {
        print(
            '🖼️ [COMPRESSION] Starting compression for file: ${imageFile.path}');
        print(
            '🖼️ [COMPRESSION] Original size: ${CompressionResult._formatFileSize(originalSize)}');
      }

      // Get image dimensions
      final imageInfo = await _getImageInfo(imageFile);
      final originalWidth = imageInfo['width'] as int;
      final originalHeight = imageInfo['height'] as int;

      if (kDebugMode) {
        print(
            '🖼️ [COMPRESSION] Original dimensions: ${originalWidth}x$originalHeight');
      }

      // Calculate target dimensions maintaining aspect ratio
      final targetDimensions =
          _calculateTargetDimensions(originalWidth, originalHeight);
      final targetWidth = targetDimensions['width']!;
      final targetHeight = targetDimensions['height']!;

      if (kDebugMode) {
        print(
            '🖼️ [COMPRESSION] Target dimensions: ${targetWidth}x$targetHeight');
      }

      // Compress with adaptive quality
      File compressedFile = await _compressWithAdaptiveQuality(
        imageFile,
        targetWidth,
        targetHeight,
        originalSize,
      );

      final compressedSize = await compressedFile.length();
      final compressionRatio = (originalSize - compressedSize) / originalSize;

      if (kDebugMode) {
        print(
            '🖼️ [COMPRESSION] Compressed size: ${CompressionResult._formatFileSize(compressedSize)}');
        print(
            '🖼️ [COMPRESSION] Compression ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%');
      }

      return CompressionResult(
        compressedFile: compressedFile,
        originalSizeBytes: originalSize,
        compressedSizeBytes: compressedSize,
        compressionRatio: compressionRatio,
        width: targetWidth,
        height: targetHeight,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [COMPRESSION] Error compressing image: $e');
      }

      if (e is ImageCompressionException) {
        rethrow;
      }

      throw ImageCompressionException(
          'Failed to compress image: ${e.toString()}');
    }
  }

  /// Validate input file meets basic requirements
  Future<void> _validateInputFile(File imageFile) async {
    // Check if file exists
    if (!await imageFile.exists()) {
      throw const ImageCompressionException('Image file does not exist');
    }

    // Check file size
    final fileSize = await imageFile.length();
    if (fileSize > _maxFileSizeBytes) {
      throw ImageCompressionException(
          'Image file too large. Maximum size: ${CompressionResult._formatFileSize(_maxFileSizeBytes)}');
    }

    if (fileSize == 0) {
      throw const ImageCompressionException('Image file is empty');
    }

    // Check file extension
    final extension = imageFile.path.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw const ImageCompressionException(
          'Unsupported image format. Supported: JPEG, PNG, WebP');
    }
  }

  /// Get image dimensions and basic info
  Future<Map<String, dynamic>> _getImageInfo(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      return {
        'width': image.width,
        'height': image.height,
        'format': imageFile.path.toLowerCase().split('.').last,
      };
    } catch (e) {
      throw ImageCompressionException(
          'Failed to read image info: ${e.toString()}');
    }
  }

  /// Calculate target dimensions maintaining aspect ratio
  Map<String, int> _calculateTargetDimensions(
      int originalWidth, int originalHeight) {
    // If already smaller than target, keep original size
    if (originalWidth <= _targetMaxWidth &&
        originalHeight <= _targetMaxHeight) {
      return {'width': originalWidth, 'height': originalHeight};
    }

    final aspectRatio = originalWidth / originalHeight;

    int targetWidth, targetHeight;

    if (aspectRatio > 1) {
      // Landscape - width is limiting factor
      targetWidth = _targetMaxWidth;
      targetHeight = (_targetMaxWidth / aspectRatio).round();
    } else {
      // Portrait or square - height is limiting factor
      targetHeight = _targetMaxHeight;
      targetWidth = (_targetMaxHeight * aspectRatio).round();
    }

    return {'width': targetWidth, 'height': targetHeight};
  }

  /// Compress with adaptive quality to meet file size requirements
  Future<File> _compressWithAdaptiveQuality(
    File inputFile,
    int targetWidth,
    int targetHeight,
    int originalSize,
  ) async {
    int quality = _defaultQuality;
    File? compressedFile;

    // Try different quality levels until we meet the target file size
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        compressedFile = await _performCompression(
          inputFile,
          targetWidth,
          targetHeight,
          quality,
        );

        final compressedSize = await compressedFile.length();

        if (kDebugMode) {
          print(
              '🖼️ [COMPRESSION] Attempt $attempt - Quality: $quality%, Size: ${CompressionResult._formatFileSize(compressedSize)}');
        }

        // If we've met the target size or quality is too low, return this result
        if (compressedSize <= _targetFileSizeBytes || quality <= 50) {
          return compressedFile;
        }

        // Reduce quality for next attempt
        quality = (quality * 0.8).round();

        // Clean up the current file if we're going to try again
        if (attempt < 4) {
          await compressedFile.delete();
        }
      } catch (e) {
        // Clean up any partial file
        if (compressedFile != null && await compressedFile.exists()) {
          await compressedFile.delete();
        }
        throw ImageCompressionException(
            'Compression attempt $attempt failed: ${e.toString()}');
      }
    }

    // This shouldn't happen, but just in case
    return compressedFile!;
  }

  /// Perform the actual compression using flutter_image_compress
  Future<File> _performCompression(
    File inputFile,
    int width,
    int height,
    int quality,
  ) async {
    try {
      // Generate unique output filename
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/compressed_${_uuid.v4()}.jpg';

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        inputFile.absolute.path,
        minWidth: width,
        minHeight: height,
        quality: quality,
        format: CompressFormat.jpeg, // Always output as JPEG for consistency
      );

      if (compressedBytes == null) {
        throw const ImageCompressionException(
            'Compression returned null result');
      }

      final compressedFile = File(outputPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      throw ImageCompressionException(
          'Platform compression failed: ${e.toString()}');
    }
  }

  /// Web-specific compression using HTML5 Canvas (when running on web)
  Future<File> _performWebCompression(
    File inputFile,
    int width,
    int height,
    int quality,
  ) async {
    if (!kIsWeb) {
      throw const ImageCompressionException(
          'Web compression called on non-web platform');
    }

    try {
      // For web, we need to handle this differently
      // This is a placeholder - in practice, you'd use HTML5 Canvas API
      // or a web-compatible image compression library

      final bytes = await inputFile.readAsBytes();
      final compressedBytes =
          await _compressWebBytes(bytes, width, height, quality);

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/compressed_web_${_uuid.v4()}.jpg';
      final compressedFile = File(outputPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      throw ImageCompressionException(
          'Web compression failed: ${e.toString()}');
    }
  }

  /// Compress bytes for web platform
  Future<Uint8List> _compressWebBytes(
    Uint8List inputBytes,
    int width,
    int height,
    int quality,
  ) async {
    // This is a simplified implementation
    // In practice, you would use HTML5 Canvas API through dart:html
    // or a web-compatible image processing library

    // For now, return the original bytes with a warning
    if (kDebugMode) {
      print(
          '⚠️ [COMPRESSION] Web compression not fully implemented, returning original bytes');
    }

    return inputBytes;
  }

  /// Clean up temporary compressed files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File && file.path.contains('compressed_')) {
          // Only delete files older than 1 hour to avoid deleting active files
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);

          if (age.inHours > 1) {
            await file.delete();
            if (kDebugMode) {
              print('🗑️ [COMPRESSION] Cleaned up temp file: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [COMPRESSION] Failed to cleanup temp files: $e');
      }
    }
  }

  /// Validate and get preview info for an image without compressing
  Future<Map<String, dynamic>> getImagePreview(File imageFile) async {
    try {
      await _validateInputFile(imageFile);
      final imageInfo = await _getImageInfo(imageFile);
      final fileSize = await imageFile.length();

      final targetDimensions = _calculateTargetDimensions(
        imageInfo['width'],
        imageInfo['height'],
      );

      return {
        'isValid': true,
        'originalWidth': imageInfo['width'],
        'originalHeight': imageInfo['height'],
        'targetWidth': targetDimensions['width'],
        'targetHeight': targetDimensions['height'],
        'originalSize': fileSize,
        'originalSizeFormatted': CompressionResult._formatFileSize(fileSize),
        'estimatedCompressedSize': (fileSize * 0.3).round(), // Rough estimate
        'format': imageInfo['format'],
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }
}
