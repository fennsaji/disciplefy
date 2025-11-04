// ============================================================================
// Web Notification Permission Handler
// ============================================================================
// Manages browser notification permission requests
// Handles permission status checking and user consent

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
      print(
          '[FCM Permission] 🔔 Requesting notification permission from browser...');

      final settings = await _firebaseMessaging.requestPermission();

      print('[FCM Permission] 📋 Permission settings received:');
      print(
          '[FCM Permission]    - authorizationStatus: ${settings.authorizationStatus}');
      print('[FCM Permission]    - alert: ${settings.alert}');
      print('[FCM Permission]    - announcement: ${settings.announcement}');
      print('[FCM Permission]    - badge: ${settings.badge}');
      print('[FCM Permission]    - sound: ${settings.sound}');

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (granted) {
        print('[FCM Permission] ✅ Permission GRANTED - notifications enabled');
      } else {
        print(
            '[FCM Permission] ❌ Permission DENIED - status: ${settings.authorizationStatus}');
        print(
            '[FCM Permission] ⚠️  User needs to allow notifications in browser settings');
      }

      return granted;
    } catch (e, stackTrace) {
      print('[FCM Permission] ❌ Permission request error: $e');
      print('[FCM Permission] Stack trace: $stackTrace');
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
      if (kDebugMode) {
        print('[FCM Permission] Error getting permission status: $e');
      }
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Check if notifications are currently enabled
  Future<bool> areNotificationsEnabled() async {
    final status = await getPermissionStatus();
    return status == AuthorizationStatus.authorized;
  }
}
