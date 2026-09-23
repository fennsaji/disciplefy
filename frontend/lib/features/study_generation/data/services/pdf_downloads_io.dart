import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/logger.dart';

/// Android's public downloads folder. Guides land in a Disciplefy subfolder so
/// they sit together and are easy to find from a file manager.
const _androidDownloadsDir = '/storage/emulated/0/Download';
const _appFolderName = 'Disciplefy';

/// Writes [bytes] to `Download/Disciplefy/[fileName]` and returns the path.
///
/// Returns null when the file could not be persisted — iOS (which has no
/// shared downloads folder), a denied permission, or a failed write. The
/// caller treats null as "share the bytes directly instead".
Future<String?> savePdfToDownloads(Uint8List bytes, String fileName) async {
  if (!Platform.isAndroid) return null;
  if (!await _ensureWritePermission()) return null;

  try {
    // A no-op when the folder is already there.
    final dir = await Directory('$_androidDownloadsDir/$_appFolderName')
        .create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e, s) {
    Logger.error('Failed to save PDF to downloads', error: e, stackTrace: s);
    return null;
  }
}

/// WRITE_EXTERNAL_STORAGE is only meaningful up to Android 10 (API 29). From
/// Android 11 an app may write into the shared Downloads collection without
/// holding any permission, and the request would be auto-denied anyway.
Future<bool> _ensureWritePermission() async {
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt >= 30) return true;
  return (await Permission.storage.request()).isGranted;
}
