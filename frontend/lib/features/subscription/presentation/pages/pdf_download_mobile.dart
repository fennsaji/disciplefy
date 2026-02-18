// Mobile-specific PDF download implementation
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Download PDF on mobile platform by saving to downloads directory
Future<String> downloadPdfBytes(Uint8List bytes, String fileName) async {
  final directory = await getDownloadsDirectory();
  if (directory == null) {
    throw Exception('Could not access downloads directory');
  }

  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  return filePath;
}
