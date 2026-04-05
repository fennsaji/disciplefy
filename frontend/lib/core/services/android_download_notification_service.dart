import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages the Android foreground service and progress notifications for
/// learning path downloads.
///
/// The foreground service keeps Android from killing the app during download.
/// Progress notifications are updated via flutter_local_notifications.
/// The actual download logic runs in the main Dart isolate.
class AndroidDownloadNotificationService {
  static const String _channelId = 'lp_download';
  static const String _channelName = 'Learning Path Downloads';
  static const int _progressNotificationId = 2001;
  static const int _completionNotificationId = 2002;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Returns true only when running on a real Android device/emulator where
  /// platform channels are registered. Returns false in unit-test environments
  /// and on iOS/web even if [defaultTargetPlatform] reports Android.
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call once after Hive init in main.dart.
  static Future<void> configure() async {
    if (!_isAndroid) return;

    // Initialize flutter_local_notifications for Android
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initSettings);

    // Create notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shows learning path download progress',
      importance: Importance.low,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure background service (foreground-service holder only)
    final service = FlutterBackgroundService();
    try {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onBackgroundServiceStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'Disciplefy',
          initialNotificationContent: 'Download starting...',
          foregroundServiceNotificationId: _progressNotificationId,
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );
    } catch (_) {
      // Platform channel not available in test environments — safe to ignore.
    }
  }

  /// Start the Android foreground service.
  static Future<void> startForeground(String pathTitle) async {
    if (!_isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('setTitle', {'title': 'Downloading "$pathTitle"'});
    } catch (_) {
      // Platform channel not available in test environments — safe to ignore.
    }
  }

  /// Update the ongoing progress notification.
  static Future<void> updateProgress({
    required String pathTitle,
    required int completed,
    required int total,
  }) async {
    if (!_isAndroid) return;
    try {
      FlutterBackgroundService().invoke('update', {
        'title': 'Downloading "$pathTitle"',
        'content': '$completed of $total guides ready',
      });
    } catch (_) {
      // Platform channel not available in test environments — safe to ignore.
    }
  }

  /// Show completion notification and stop the foreground service.
  static Future<void> completeDownload(String pathTitle, int total) async {
    if (!_isAndroid) return;
    try {
      FlutterBackgroundService().invoke('stop', {});

      const details = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Learning Path Downloads',
      );
      await _notifications.show(
        _completionNotificationId,
        '"$pathTitle" ready offline',
        'All $total guides downloaded - Tap to open',
        const NotificationDetails(android: details),
      );
    } catch (_) {
      // Platform channel not available in test environments — safe to ignore.
    }
  }

  /// Stop foreground service (call on pause/cancel).
  static void stopForeground() {
    if (!_isAndroid) return;
    try {
      FlutterBackgroundService().invoke('stop', {});
    } catch (_) {
      // Platform channel not available in test environments — safe to ignore.
    }
  }
}

/// Entry point for flutter_background_service background isolate.
/// Runs in a separate Dart isolate — only manages the notification text.
@pragma('vm:entry-point')
void _onBackgroundServiceStart(ServiceInstance service) {
  // Cast to AndroidServiceInstance to access setForegroundNotificationInfo.
  final android = service is AndroidServiceInstance ? service : null;

  service.on('update').listen((event) {
    if (event == null) return;
    android?.setForegroundNotificationInfo(
      title: event['title'] as String? ?? 'Downloading...',
      content: event['content'] as String? ?? '',
    );
  });

  service.on('setTitle').listen((event) {
    if (event == null) return;
    android?.setForegroundNotificationInfo(
      title: event['title'] as String? ?? 'Downloading...',
      content: 'Preparing...',
    );
  });

  service.on('stop').listen((_) => service.stopSelf());
}
