// Stub implementation for unsupported platforms
import 'dart:typed_data';

/// Stub download function - throws error on unsupported platforms
Future<String> downloadPdfBytes(Uint8List bytes, String fileName) async {
  throw UnsupportedError('PDF download is not supported on this platform');
}
