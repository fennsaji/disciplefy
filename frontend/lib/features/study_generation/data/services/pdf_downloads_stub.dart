// Platforms with no public downloads folder to write to (web).
import 'dart:typed_data';

/// No-op counterpart of the `dart:io` implementation. Returning null tells the
/// caller nothing was persisted, so it should share the bytes directly.
Future<String?> savePdfToDownloads(Uint8List bytes, String fileName) async =>
    null;
