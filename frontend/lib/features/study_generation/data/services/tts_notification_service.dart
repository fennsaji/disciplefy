import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/services/android_download_notification_service.dart';
import '../../../../core/utils/logger.dart';

/// Manages the notification displayed while study guide TTS is playing.
///
/// On Android: uses a mediaPlayback foreground service so the OS keeps the
/// process alive during background audio playback.
/// On other platforms: shows an ongoing notification via flutter_local_notifications.
class TtsNotificationService {
  static const int _notificationId = 9001;
  static const String _channelId = 'tts_playback';
  static const String _channelName = 'Study Guide Playback';
  static const String _channelDescription =
      'Shows while a study guide is being read aloud';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Initialize the TTS notification channel (non-Android platforms only).
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isAndroid) return; // Android uses the foreground service channel

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    Logger.debug('🔔 [TTS Notification] Channel initialized');
  }

  /// Show notification for TTS playback.
  /// On Android: starts the mediaPlayback foreground service.
  /// On other platforms: shows an ongoing notification.
  Future<void> showPlaybackNotification({required String sectionName}) async {
    if (kIsWeb) return;

    if (_isAndroid) {
      await AndroidDownloadNotificationService.startTtsForeground(sectionName);
      Logger.debug(
          '🔔 [TTS Notification] Foreground service started: $sectionName');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(''),
    );

    await _localNotifications.show(
      _notificationId,
      'Disciplefy - Reading Study Guide',
      sectionName,
      const NotificationDetails(android: androidDetails),
    );

    Logger.debug('🔔 [TTS Notification] Showing: $sectionName');
  }

  /// Update the notification with the current section.
  Future<void> updateSection(String sectionName) async {
    if (kIsWeb) return;

    if (_isAndroid) {
      await AndroidDownloadNotificationService.updateTtsSection(sectionName);
      return;
    }

    await showPlaybackNotification(sectionName: sectionName);
  }

  /// Dismiss the playback notification and stop the foreground service.
  Future<void> dismissNotification() async {
    if (kIsWeb) return;

    if (_isAndroid) {
      AndroidDownloadNotificationService.stopTtsForeground();
      Logger.debug('🔔 [TTS Notification] Foreground service stopped');
      return;
    }

    await _localNotifications.cancel(_notificationId);
    Logger.debug('🔔 [TTS Notification] Dismissed');
  }
}
