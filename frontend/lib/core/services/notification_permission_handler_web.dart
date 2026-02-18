// ============================================================================
// Web Notification Permission Handler
// ============================================================================
// Manages browser notification permission requests
// Handles permission status checking and user consent

import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/logger.dart';

/// Handles notification permission requests for web platform
class NotificationPermissionHandlerWeb {
  final FirebaseMessaging _firebaseMessaging;

  NotificationPermissionHandlerWeb({
    required FirebaseMessaging firebaseMessaging,
  }) : _firebaseMessaging = firebaseMessaging;

  // ============================================================================
  // Permission Request
  // ============================================================================

  /// Request notification permissions from the browser
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermissions() async {
    try {
      Logger.debug(
          '[FCM Permission] 🔔 Requesting notification permission from browser...');

      final settings = await _firebaseMessaging.requestPermission();

      Logger.debug('[FCM Permission] 📋 Permission settings received:');
      Logger.debug(
          '[FCM Permission]    - authorizationStatus: ${settings.authorizationStatus}');
      Logger.debug('[FCM Permission]    - alert: ${settings.alert}');
      Logger.debug(
          '[FCM Permission]    - announcement: ${settings.announcement}');
      Logger.debug('[FCM Permission]    - badge: ${settings.badge}');
      Logger.debug('[FCM Permission]    - sound: ${settings.sound}');

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (granted) {
        Logger.error(
            '[FCM Permission] ✅ Permission GRANTED - notifications enabled');
      } else {
        Logger.error(
            '[FCM Permission] ❌ Permission DENIED - status: ${settings.authorizationStatus}');
        Logger.warning(
            '[FCM Permission] ⚠️  User needs to allow notifications in browser settings');
      }

      return granted;
    } catch (e, stackTrace) {
      Logger.error('[FCM Permission] ❌ Permission request error: $e');
      Logger.debug('[FCM Permission] Stack trace: $stackTrace');
      return false;
    }
  }

  // ============================================================================
  // Permission Status Check
  // ============================================================================

  /// Get current notification permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      Logger.error('[FCM Permission] Error getting permission status: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Check if notifications are currently enabled
  Future<bool> areNotificationsEnabled() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized;
  }
}
