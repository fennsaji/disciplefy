import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation code must never put `failure.message` straight into state or a
/// snackbar: those strings carry server details, status codes and exception
/// text. A fellowship screen shipped
/// "AppException: REQUEST_FAILED - Request failed: TimeoutException after
/// 0:00:10.000000: Future not completed" to users this way.
///
/// Everything user-visible goes through ErrorMessageSanitizer instead.
void main() {
  test('no presentation code surfaces failure.message directly', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.path.contains('/presentation/') &&
          !entity.path.contains('/screens/')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `state.failure.message` is a different shape and is used in
        // kDebugMode-guarded logging, so only flag the bare local.
        if (RegExp(r'(?<![\w.])failure\.message').hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Route these through ErrorMessageSanitizer.sanitize(failure):\n'
          '${offenders.join('\n')}',
    );
  });
}
