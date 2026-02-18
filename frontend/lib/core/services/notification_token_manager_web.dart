// ============================================================================
// Web Notification Token Manager
// ============================================================================
// Manages FCM token lifecycle: retrieval, registration, and deletion
// Handles token refresh and backend synchronization

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Manages FCM token operations for web platform
class NotificationTokenManagerWeb {
  final SupabaseClient _supabaseClient;
  final FirebaseMessaging _firebaseMessaging;

  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  NotificationTokenManagerWeb({
    required SupabaseClient supabaseClient,
    required FirebaseMessaging firebaseMessaging,
  })  : _supabaseClient = supabaseClient,
        _firebaseMessaging = firebaseMessaging;

  // ============================================================================
  // Getters
  // ============================================================================

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Mask FCM token for secure logging (show first 6 and last 4 chars)
  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  // ============================================================================
  // Token Retrieval
  // ============================================================================

  /// Get FCM registration token with VAPID key
  Future<String?> getFCMToken() async {
    try {
      // Wait for service worker to be ready before requesting token
      await Future.delayed(const Duration(seconds: 2));

      _fcmToken = await _firebaseMessaging.getToken(
        vapidKey:
            'BMxX8YF4KnTfRuJ5bzJSQe4GunTg8D2-BCO2xzXpzXZAo2RLdo2AY7H2HQ9iW6gOaHIsElv__EUH8ImgHnLSSGk',
      );

      if (_fcmToken != null) {
        Logger.debug('[FCM Token] ✅ Token received: ${_maskToken(_fcmToken)}');
      } else {
        Logger.warning(
            '[FCM Token] ❌ Failed to get FCM token (service worker not registered, invalid VAPID key, or unsupported browser)');
      }

      return _fcmToken;
    } catch (e, stackTrace) {
      Logger.error('[FCM Token] ❌ Token retrieval error: $e',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Set up listener for token refresh events
  void setupTokenRefreshListener(Future<void> Function() onTokenRefresh) {
    _tokenRefreshSubscription =
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      Logger.debug('[FCM Token] 🔄 Token refreshed: ${_maskToken(newToken)}');
      _fcmToken = newToken;

      try {
        await onTokenRefresh();
      } catch (e, stackTrace) {
        Logger.error('[FCM Token] ❌ Error during token refresh callback: $e',
            error: e, stackTrace: stackTrace);
      }
    });
  }

  // ============================================================================
  // Backend Registration
  // ============================================================================

  /// Register FCM token with Supabase backend
  Future<bool> registerTokenWithBackend() async {
    if (_fcmToken == null) {
      Logger.debug('[FCM Token] No token to register');
      return false;
    }

    try {
      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        Logger.debug(
            '[FCM Token] User not authenticated, skipping registration');
        return false;
      }

      if (currentUser.isAnonymous) {
        Logger.debug(
            '[FCM Token] Anonymous user, skipping push notification registration');
        return false;
      }

      if (kDebugMode) {
        Logger.debug(
            '[FCM Token] 📤 Registering token for user: ${currentUser.id}');
      }

      final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        body: {
          'fcmToken': _fcmToken,
          'platform': 'web',
          'timezoneOffsetMinutes': timezoneOffset,
        },
      );

      if (response.status == 200) {
        Logger.debug('[FCM Token] ✅ Token registered successfully');
        return true;
      } else {
        Logger.error(
            '[FCM Token] ❌ Token registration failed | status: ${response.status}');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('[FCM Token] ❌ Token registration error: $e',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // ============================================================================
  // Backend Unregistration
  // ============================================================================

  /// Unregister token from backend (called on logout/session expiry)
  Future<bool> unregisterTokenFromBackend() async {
    if (_fcmToken == null) return false;

    try {
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.delete,
        body: {
          'fcmToken': _fcmToken,
        },
      );

      if (response.status == 200) {
        Logger.debug('[FCM Token] ✅ Token unregistered from backend');
        return true;
      } else {
        Logger.error(
            '[FCM Token] ❌ Token unregistration failed | status: ${response.status}');
        return false;
      }
    } catch (e) {
      Logger.error('[FCM Token] ❌ Error unregistering token: $e');
      return false;
    }
  }

  // ============================================================================
  // Token Deletion
  // ============================================================================

  /// Delete FCM token completely (opt-out of notifications)
  Future<void> deleteToken() async {
    try {
      await unregisterTokenFromBackend();
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      Logger.debug('[FCM Token] ✅ Token deleted');
    } catch (e) {
      Logger.error('[FCM Token] ❌ Token deletion error: $e');
    }
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose resources and cancel subscriptions
  void dispose() {
    _tokenRefreshSubscription?.cancel();
  }
}
