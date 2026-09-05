import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AndroidDownloadNotificationService.configure() used to be awaited in main()
/// before runApp(), where it prepared a notification channel and a background
/// service that only downloads and TTS playback use — none of it needed to draw
/// the first frame. It now configures itself on first actual use.
///
/// The danger in that move is silence: configure() swallows platform errors by
/// design, so an entry point that forgot to configure would look identical to a
/// working one — downloads and TTS would just quietly have no foreground
/// service, which on Android means the OS is free to kill the process
/// mid-download or mid-playback.
///
/// A runtime test cannot cover this: both flutter_local_notifications and
/// flutter_background_service gate on dart:io's Platform.isAndroid and throw
/// before any mockable method channel is reached, so proving the real plugin
/// sequence needs a device (or injecting both plugins purely for tests). What
/// is worth guarding cheaply is the coupling itself — that every entry point
/// which needs the configured state still asks for it. Same source-reading
/// approach as the backend's notification-type-constraint drift test.
void main() {
  final source = File(
    'lib/core/services/android_download_notification_service.dart',
  ).readAsStringSync();

  /// Returns the body of a static method, from its signature to the closing
  /// brace at method indentation.
  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature not found — was it renamed?');
    final end = source.indexOf('\n  }', start);
    expect(end, isNot(-1), reason: 'Could not find the end of $signature');
    return source.substring(start, end);
  }

  group('entry points needing the configured state ask for it', () {
    // startService() is a no-op unless configure() has run, so a download or
    // TTS session started without it silently has no foreground service.
    for (final signature in [
      'static Future<void> startForeground(',
      'static Future<void> startTtsForeground(',
      // Shows a notification directly through the plugin, which needs
      // initialize() to have run.
      'static Future<void> completeDownload(',
    ]) {
      test('$signature awaits _ensureConfigured()', () {
        expect(
          bodyOf(signature),
          contains('await _ensureConfigured()'),
          reason: 'Removing this reintroduces the silent-no-foreground-service '
              'bug that deferring configure() out of main() risks.',
        );
      });
    }
  });

  test('main() no longer configures it on the startup path', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      main,
      isNot(contains('AndroidDownloadNotificationService.configure()')),
      reason: 'Awaiting configure() in main() puts notification-channel and '
          'background-service setup back on the pre-first-frame path.',
    );
  });

  test('configure() guards its whole body, not just the service call', () {
    // Reaching configure() lazily made it reachable from tests and from any
    // context without the notification plugin, where initialize() throws a
    // LateInitializationError. That used to escape, failing three
    // learning-path download tests.
    final configureBody = bodyOf('static Future<void> configure(');
    final tryIndex = configureBody.indexOf('try {');
    final initIndex = configureBody.indexOf('_notifications.initialize(');

    expect(tryIndex, isNot(-1), reason: 'configure() must guard its body');
    expect(initIndex, isNot(-1));
    expect(
      tryIndex,
      lessThan(initIndex),
      reason: 'initialize() must sit inside the try, or it throws out of '
          'configure() wherever the plugin is unavailable.',
    );
  });
}
