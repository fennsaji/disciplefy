// Web-specific PDF download implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Blob, Url;
import 'dart:typed_data';

/// Download PDF on web platform using browser download
Future<String> downloadPdfBytes(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  // Return fileName since web downloads go to browser's default download location
  return fileName;
}
