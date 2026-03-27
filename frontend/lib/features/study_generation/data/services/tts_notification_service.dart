import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/utils/logger.dart';

/// Manages an ongoing notification displayed while study guide TTS is playing.
///
/// This notification:
/// - Keeps the process visible to Android and prevents aggressive battery kills
/// - Informs the user that audio is playing so they can return to the app
/// - Is automatically dismissed when TTS stops
class TtsNotificationService {
  static const int _notificationId = 9001;
  static const String _channelId = 'tts_playback';
  static const String _channelName = 'Study Guide Playback';
  static const String _channelDescription =
      'Shows while a study guide is being read aloud';

  // Own plugin instance — shares the same native plugin with NotificationService.
  // NotificationService.initialize() must run before this service is used.
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize the TTS notification channel.
  /// Call this after NotificationService.initialize() completes at app startup.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

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

  /// Show an ongoing notification for TTS playback.
  /// [sectionName] is displayed as the notification body (e.g., "Summary").
  Future<void> showPlaybackNotification({required String sectionName}) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

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

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      _notificationId,
      'Disciplefy - Reading Study Guide',
      sectionName,
      details,
    );

    Logger.debug('🔔 [TTS Notification] Showing: $sectionName');
  }

  /// Update the notification body with the current section name.
  Future<void> updateSection(String sectionName) async {
    await showPlaybackNotification(sectionName: sectionName);
  }

  /// Dismiss the playback notification.
  Future<void> dismissNotification() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    await _localNotifications.cancel(_notificationId);
    Logger.debug('🔔 [TTS Notification] Dismissed');
  }
}
