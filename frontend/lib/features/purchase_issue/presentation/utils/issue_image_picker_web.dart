// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation of issue image picker using dart:html
class IssueImagePicker {
  /// Pick an image file from the file system (web-only)
  ///
  /// Returns a map containing:
  /// - 'data': Uint8List of the image bytes
  /// - 'name': String filename
  /// - 'type': String MIME type
  ///
  /// Returns null if user cancels or selection fails
  static Future<Map<String, dynamic>?> pickImage() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/jpeg,image/png,image/webp';
    input.click();

    await input.onChange.first;
    if (input.files?.isNotEmpty == true) {
      final file = input.files!.first;

      // Check file size (5MB max)
      if (file.size > 5 * 1024 * 1024) {
        return {
          'error': 'File too large. Maximum size is 5MB.',
        };
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final data = reader.result as List<int>;

      return {
        'data': Uint8List.fromList(data),
        'name': file.name,
        'type': file.type,
      };
    }

    return null;
  }
}
