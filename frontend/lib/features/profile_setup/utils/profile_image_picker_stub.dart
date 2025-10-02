import 'dart:typed_data';

/// Stub implementation of profile image picker for non-web platforms
class ProfileImagePicker {
  /// Pick an image file from the file system (stub for non-web platforms)
  ///
  /// Returns null on non-web platforms as image picking is not supported
  /// in the current implementation.
  ///
  /// Mobile implementations should use image_picker package or similar.
  static Future<Map<String, dynamic>?> pickImage() async {
    // Return null for non-web platforms
    // Mobile implementation would use image_picker package here
    return null;
  }
}
