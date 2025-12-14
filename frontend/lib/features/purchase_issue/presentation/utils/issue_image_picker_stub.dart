import 'dart:typed_data';

/// Stub implementation for non-web platforms
/// This file is used as the default implementation
class IssueImagePicker {
  /// Pick an image file from the file system
  ///
  /// Returns a map containing:
  /// - 'data': Uint8List of the image bytes
  /// - 'name': String filename
  /// - 'type': String MIME type
  ///
  /// Returns null if user cancels or selection fails
  static Future<Map<String, dynamic>?> pickImage() async {
    // TODO: Implement for mobile using image_picker package
    // For now, return null (not implemented)
    return null;
  }
}
