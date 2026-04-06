import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages the Android foreground service for two use cases:
/// 1. Learning path downloads (actual download runs in main isolate; service shows notifications)
/// 2. Study guide TTS audio playback (mediaPlayback)
///
/// Both share a single foreground service instance so Android keeps the
/// process alive during background audio playback and content downloads.
/// Note: dataSync foreground service type deprecated in Android 15; mediaPlayback covers both.
class AndroidDownloadNotificationService {
  static const String _channelId = 'lp_download';
  static const String _channelName = 'Disciplefy Background';
  static const int _progressNotificationId = 2001;
  static const int _completionNotificationId = 2002;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Tracks active use cases so the service stops only when both are idle.
  static bool _downloadActive = false;
  static bool _ttsActive = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call once after Hive init in main.dart.
  static Future<void> configure() async {
    if (!_isAndroid) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shows during downloads and audio playback',
      importance: Importance.low,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    try {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onBackgroundServiceStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'Disciplefy',
          initialNotificationContent: '',
          foregroundServiceNotificationId: _progressNotificationId,
          foregroundServiceTypes: [
            AndroidForegroundType.mediaPlayback,
          ],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );
    } catch (_) {
      // Platform channel not available in test environments.
    }
  }

  // ─── Download methods ────────────────────────────────────────────────────

  static Future<void> startForeground(String pathTitle) async {
    if (!_isAndroid) return;
    _downloadActive = true;
    try {
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('startDownload', {
        'title': 'Downloading "$pathTitle"',
        'content': 'Starting...',
      });
    } catch (_) {}
  }

  static Future<void> updateProgress({
    required String pathTitle,
    required int completed,
    required int total,
  }) async {
    if (!_isAndroid) return;
    try {
      FlutterBackgroundService().invoke('updateDownload', {
        'title': 'Downloading "$pathTitle"',
        'content': '$completed of $total guides ready',
      });
    } catch (_) {}
  }

  static Future<void> completeDownload(String pathTitle, int total) async {
    if (!_isAndroid) return;
    _downloadActive = false;
    try {
      FlutterBackgroundService().invoke('stopDownload', {});

      const details = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Shows during downloads and audio playback',
      );
      await _notifications.show(
        _completionNotificationId,
        '"$pathTitle" ready offline',
        'All $total guides downloaded - Tap to open',
        const NotificationDetails(android: details),
      );
    } catch (_) {}
  }

  static void stopForeground() {
    if (!_isAndroid) return;
    _downloadActive = false;
    try {
      FlutterBackgroundService().invoke('stopDownload', {});
    } catch (_) {}
  }

  // ─── TTS / media playback methods ────────────────────────────────────────

  /// Start foreground service for TTS audio playback.
  static Future<void> startTtsForeground(String sectionName) async {
    if (!_isAndroid) return;
    _ttsActive = true;
    try {
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('startTts', {'section': sectionName});
    } catch (_) {}
  }

  /// Update the TTS notification with the current section.
  static Future<void> updateTtsSection(String sectionName) async {
    if (!_isAndroid) return;
    try {
      FlutterBackgroundService().invoke('updateTts', {'section': sectionName});
    } catch (_) {}
  }

  /// Stop the TTS foreground service (stops service if no download active).
  static void stopTtsForeground() {
    if (!_isAndroid) return;
    _ttsActive = false;
    try {
      FlutterBackgroundService().invoke('stopTts', {});
    } catch (_) {}
  }
}

/// Entry point for the background service isolate.
/// Handles both download progress and TTS playback notifications.
@pragma('vm:entry-point')
void _onBackgroundServiceStart(ServiceInstance service) {
  final android = service is AndroidServiceInstance ? service : null;

  bool downloadActive = false;
  bool ttsActive = false;

  void stopIfIdle() {
    if (!downloadActive && !ttsActive) service.stopSelf();
  }

  service.on('startDownload').listen((event) {
    if (event == null) return;
    downloadActive = true;
    android?.setForegroundNotificationInfo(
      title: event['title'] as String? ?? 'Downloading...',
      content: event['content'] as String? ?? '',
    );
  });

  service.on('updateDownload').listen((event) {
    if (event == null || !downloadActive) return;
    android?.setForegroundNotificationInfo(
      title: event['title'] as String? ?? 'Downloading...',
      content: event['content'] as String? ?? '',
    );
  });

  service.on('stopDownload').listen((_) {
    downloadActive = false;
    if (ttsActive) {
      android?.setForegroundNotificationInfo(
        title: '📖 Reading Study Guide',
        content: '',
      );
    } else {
      stopIfIdle();
    }
  });

  service.on('startTts').listen((event) {
    if (event == null) return;
    ttsActive = true;
    if (!downloadActive) {
      android?.setForegroundNotificationInfo(
        title: '📖 Reading Study Guide',
        content: event['section'] as String? ?? '',
      );
    }
  });

  service.on('updateTts').listen((event) {
    if (event == null || !ttsActive || downloadActive) return;
    android?.setForegroundNotificationInfo(
      title: '📖 Reading Study Guide',
      content: event['section'] as String? ?? '',
    );
  });

  service.on('stopTts').listen((_) {
    ttsActive = false;
    stopIfIdle();
  });
}
