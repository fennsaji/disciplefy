// ============================================================================
// Web Notification Token Manager
// ============================================================================
// Manages FCM token lifecycle: retrieval, registration, and deletion
// Handles token refresh and backend synchronization

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (token.length <= 10) return '***'; // Too short to mask safely

    final prefix = token.substring(0, 6);
    final suffix = token.substring(token.length - 4);
    return '$prefix...$suffix';
  }

  // ============================================================================
  // Token Retrieval
  // ============================================================================

  /// Get FCM registration token with VAPID key
  Future<String?> getFCMToken() async {
    try {
      if (kDebugMode) print('[FCM Token] 🔑 Getting FCM token...');

      // Wait for service worker to be ready before requesting token
      if (kDebugMode) {
        print('[FCM Token] ⏳ Waiting for service worker (2 seconds)...');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (kDebugMode) {
        print('[FCM Token] ✅ Service worker wait complete');
      }

      // VAPID key from Firebase Console → Cloud Messaging → Web Push certificates
      if (kDebugMode) {
        print('[FCM Token] 🔐 Requesting token with VAPID key...');
      }
      _fcmToken = await _firebaseMessaging.getToken(
        vapidKey:
            'BMxX8YF4KnTfRuJ5bzJSQe4GunTg8D2-BCO2xzXpzXZAo2RLdo2AY7H2HQ9iW6gOaHIsElv__EUH8ImgHnLSSGk',
      );

      if (_fcmToken != null) {
        if (kDebugMode) {
          print('[FCM Token] ✅ Token received successfully');
          print('[FCM Token] 📋 Masked token: ${_maskToken(_fcmToken)}');
          print('[FCM Token] 📏 Token length: ${_fcmToken!.length} characters');
        }
      } else {
        if (kDebugMode) {
          print('[FCM Token] ❌ Failed to get FCM token');
          print('[FCM Token] ⚠️  Possible reasons:');
          print('[FCM Token]    - Service worker not registered');
          print('[FCM Token]    - VAPID key incorrect');
          print('[FCM Token]    - Browser doesn\'t support FCM');
        }
      }

      return _fcmToken;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[FCM Token] ❌ Token retrieval error: $e');
        print('[FCM Token] Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Set up listener for token refresh events
  void setupTokenRefreshListener(Future<void> Function() onTokenRefresh) {
    if (kDebugMode) {
      print('[FCM Token] 🔄 Setting up token refresh listener...');
    }

    _tokenRefreshSubscription =
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('[FCM Token] 🔄 Token refreshed');
        print('[FCM Token] 📋 New token: ${_maskToken(newToken)}');
      }
      _fcmToken = newToken;
      onTokenRefresh();
    });
  }

  // ============================================================================
  // Backend Registration
  // ============================================================================

  /// Register FCM token with Supabase backend
  Future<bool> registerTokenWithBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) {
        print('[FCM Token] ❌ No FCM token to register');
        print('[FCM Token] ⚠️  Token registration skipped');
      }
      return false;
    }

    try {
      if (kDebugMode) print('[FCM Token] 🔍 Checking user authentication...');

      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('[FCM Token] ❌ User not authenticated');
          print(
              '[FCM Token] ⚠️  Token registration skipped - user must be logged in');
        }
        return false;
      }

      if (kDebugMode) {
        print('[FCM Token] ✅ User authenticated: ${currentUser.id}');
        print('[FCM Token] 📧 User email: ${currentUser.email ?? 'null'}');
        print('[FCM Token] 🔍 Checking if user is anonymous...');
      }

      // Skip registration for anonymous/guest users
      final isAnonymous = currentUser.isAnonymous;
      if (isAnonymous) {
        if (kDebugMode) {
          print('[FCM Token] ⚠️  User is anonymous (guest)');
          print('[FCM Token] ❌ Skipping notification registration');
          print(
              '[FCM Token] ℹ️  Push notifications are only available for authenticated users');
        }
        return false;
      }

      if (kDebugMode) {
        print('[FCM Token] ✅ User is authenticated (not anonymous)');
        print('[FCM Token] 📤 Registering FCM token with backend...');
        print('[FCM Token] 🔐 Token: ${_maskToken(_fcmToken)}');
      }

      final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      if (kDebugMode) {
        print('[FCM Token] 🌍 Timezone offset: $timezoneOffset minutes');
        print('[FCM Token] 🖥️  Platform: web');
      }

      // Call edge function to register token
      if (kDebugMode) {
        print('[FCM Token] 🚀 Calling register-fcm-token edge function...');
      }

      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        body: {
          'fcmToken': _fcmToken,
          'platform': 'web',
          'timezoneOffsetMinutes': timezoneOffset,
        },
      );

      if (kDebugMode) {
        print('[FCM Token] 📥 Response received from backend');
        print('[FCM Token] 📊 Status code: ${response.status}');
        print('[FCM Token] 📋 Response data: ${response.data}');
      }

      if (response.status == 200) {
        if (kDebugMode) {
          print('[FCM Token] ✅ Token registered successfully with backend!');
          print('[FCM Token] 🎉 User will now receive push notifications');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[FCM Token] ❌ Token registration failed');
          print('[FCM Token] ⚠️  Status: ${response.status}');
          print('[FCM Token] ℹ️  Data: ${response.data}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[FCM Token] ❌ Token registration error: $e');
        print('[FCM Token] Stack trace: $stackTrace');
      }
      return false;
    }
  }

  // ============================================================================
  // Backend Unregistration
  // ============================================================================

  /// Unregister token from backend (called on logout/session expiry)
  Future<bool> unregisterTokenFromBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) {
        print('[FCM Token] No token to unregister');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('[FCM Token] 🗑️  Unregistering token from backend...');
        print('[FCM Token] Token: ${_maskToken(_fcmToken)}');
      }

      // Call DELETE endpoint to remove token
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.delete,
        body: {
          'fcmToken': _fcmToken,
        },
      );

      if (response.status == 200) {
        if (kDebugMode) {
          print('[FCM Token] ✅ Token unregistered from backend successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[FCM Token] ⚠️  Token unregistration failed');
          print('[FCM Token] Status: ${response.status}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FCM Token] ❌ Error unregistering token: $e');
      }
      return false;
    }
  }

  // ============================================================================
  // Token Deletion
  // ============================================================================

  /// Delete FCM token completely (opt-out of notifications)
  Future<void> deleteToken() async {
    try {
      if (kDebugMode) print('[FCM Token] Deleting FCM token...');

      // First unregister from backend
      await unregisterTokenFromBackend();

      // Then delete from Firebase
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;

      if (kDebugMode) print('[FCM Token] Token deleted successfully');
    } catch (e) {
      if (kDebugMode) print('[FCM Token] Token deletion error: $e');
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
