// ============================================================================
// Web Notification Service
// ============================================================================
// Manages Firebase Cloud Messaging for web platform
// Handles token registration, permission requests, and message handling

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

/// Web-specific implementation of notification service
class NotificationServiceWeb {
  final SupabaseClient _supabaseClient;
  final GoRouter _router;

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;
  bool _isInitialized = false;

  // Stream controllers for notification events
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  // Auth state subscription
  StreamSubscription<AuthState>? _authStateSubscription;

  NotificationServiceWeb({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  })  : _supabaseClient = supabaseClient,
        _router = router;

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
  // Initialization
  // ============================================================================

  /// Initialize Firebase Messaging for web
  Future<void> initialize() async {
    print(
        '[FCM Web] 🔍 Initialize called - checking if already initialized...');
    print('[FCM Web] 📊 Current _isInitialized value: $_isInitialized');

    if (_isInitialized) {
      print('[FCM Web] ⚠️  Already initialized - skipping');
      return;
    }

    try {
      print('[FCM Web] 🚀 Starting initialization...');

      // Get Firebase Messaging instance
      // Note: Firebase is already initialized in index.html
      try {
        print('[FCM Web] 📱 Getting Firebase Messaging instance...');
        _firebaseMessaging = FirebaseMessaging.instance;
        print('[FCM Web] ✅ Firebase Messaging instance obtained');
      } catch (e) {
        print('[FCM Web] ❌ Firebase instance error: $e');
        // Firebase may already be initialized in JS, continue anyway
      }

      print(
          '[FCM Web] 🔄 After Firebase instance - continuing to permissions...');

      // Check service worker availability first (CSP-safe using dart:html)
      print('[FCM Web] 🔍 Checking service worker status...');
      try {
        if (kIsWeb) {
          final serviceWorkerSupported =
              html.window.navigator.serviceWorker != null;

          if (!serviceWorkerSupported) {
            print('[FCM Web] ❌ Service Worker not supported in this browser');
          } else {
            // Wait for service worker to be ready
            final registration =
                await html.window.navigator.serviceWorker!.ready;

            if (kDebugMode) {
              print('[FCM Web] ✅ Service worker ready');
              print('[FCM Web] 📊 Scope: ${registration.scope}');
              print('[FCM Web] 📊 Active: ${registration.active != null}');
            }
          }
        }
      } catch (e) {
        print('[FCM Web] ⚠️  Service worker check error: $e');
      }

      // Request permission
      print('[FCM Web] 📋 Requesting notification permission...');
      bool hasPermission = false;
      try {
        hasPermission = await requestPermissions();
      } catch (e, stackTrace) {
        print('[FCM Web] ❌ Permission request failed with error: $e');
        print('[FCM Web] Stack trace: $stackTrace');
        print(
            '[FCM Web] ⚠️  This is likely a service worker or browser compatibility issue');
        return;
      }

      if (!hasPermission) {
        print('[FCM Web] ❌ Notification permission denied by user');
        print(
            '[FCM Web] Current permission status: ${await _firebaseMessaging?.getNotificationSettings()}');
        return;
      }
      print('[FCM Web] ✅ Notification permission granted');

      // Get FCM token with VAPID key
      print('[FCM Web] 🔑 Getting FCM token...');
      await _getFCMToken();

      if (_fcmToken != null) {
        print('[FCM Web] ✅ FCM Token obtained: ${_maskToken(_fcmToken)}');
      } else {
        print(
            '[FCM Web] ❌ Failed to get FCM token - notifications will NOT work');
      }

      // Set up foreground message listener
      print('[FCM Web] 📡 Setting up foreground message listener...');
      _setupForegroundMessageListener();

      // Set up service worker message listener for notification clicks
      print('[FCM Web] 📬 Setting up service worker message listener...');
      _setupServiceWorkerMessageListener();

      // Register token with backend if user is already authenticated
      if (_fcmToken != null) {
        print('[FCM Web] 📤 Registering token with backend...');
        await _registerTokenWithBackend();
      }

      // Listen to auth state changes to register token when user logs in
      print('[FCM Web] 👤 Setting up auth state listener...');
      _setupAuthStateListener();

      _isInitialized = true;
      print('[FCM Web] ✅ Initialization complete');
      print('[FCM Web] 📊 Summary:');
      print('[FCM Web]    - Permission: granted');
      print(
          '[FCM Web]    - FCM Token: ${_fcmToken != null ? 'obtained' : 'MISSING'}');
      print('[FCM Web]    - Foreground listener: active');
      print('[FCM Web]    - Auth listener: active');
    } catch (e, stackTrace) {
      print('[FCM Web] ❌ Initialization error: $e');
      print('[FCM Web] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ============================================================================
  // Auth State Monitoring
  // ============================================================================

  /// Set up listener for auth state changes
  void _setupAuthStateListener() {
    if (kDebugMode) print('[FCM Web] Setting up auth state listener...');

    _authStateSubscription = _supabaseClient.auth.onAuthStateChange.listen(
      (authState) {
        final event = authState.event;
        final session = authState.session;

        if (kDebugMode) {
          print('[FCM Web] Auth state changed: $event');
          print('[FCM Web] User authenticated: ${session?.user.id ?? 'null'}');
        }

        // Register token when user signs in
        if (event == AuthChangeEvent.signedIn && session != null) {
          if (kDebugMode) {
            print('[FCM Web] User signed in, registering FCM token...');
          }
          _registerTokenWithBackend();
        }

        // Delete token when user signs out or session expires
        if (event == AuthChangeEvent.signedOut ||
            event == AuthChangeEvent.tokenRefreshed && session == null) {
          if (kDebugMode) {
            print('[FCM Web] User signed out or session expired');
            print('[FCM Web] Deleting FCM token from backend...');
          }
          _unregisterTokenFromBackend();
        }
      },
    );
  }

  // ============================================================================
  // Permission Handling
  // ============================================================================

  /// Request notification permissions from the browser
  Future<bool> requestPermissions() async {
    try {
      print('[FCM Web] 🔔 Requesting notification permission from browser...');

      final settings = await _firebaseMessaging!.requestPermission();

      print('[FCM Web] 📋 Permission settings received:');
      print(
          '[FCM Web]    - authorizationStatus: ${settings.authorizationStatus}');
      print('[FCM Web]    - alert: ${settings.alert}');
      print('[FCM Web]    - announcement: ${settings.announcement}');
      print('[FCM Web]    - badge: ${settings.badge}');
      print('[FCM Web]    - sound: ${settings.sound}');

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (granted) {
        print('[FCM Web] ✅ Permission GRANTED - notifications enabled');
      } else {
        print(
            '[FCM Web] ❌ Permission DENIED - status: ${settings.authorizationStatus}');
        print(
            '[FCM Web] ⚠️  User needs to allow notifications in browser settings');
      }

      return granted;
    } catch (e, stackTrace) {
      print('[FCM Web] ❌ Permission request error: $e');
      print('[FCM Web] Stack trace: $stackTrace');
      return false;
    }
  }

  // ============================================================================
  // Token Management
  // ============================================================================

  /// Get FCM registration token
  Future<void> _getFCMToken() async {
    try {
      if (kDebugMode) print('[FCM Web] 🔑 Getting FCM token...');

      // Wait for service worker to be ready before requesting token
      if (kDebugMode) {
        print('[FCM Web] ⏳ Waiting for service worker (2 seconds)...');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (kDebugMode) {
        print('[FCM Web] ✅ Service worker wait complete');
      }

      // VAPID key from Firebase Console → Cloud Messaging → Web Push certificates
      if (kDebugMode) print('[FCM Web] 🔐 Requesting token with VAPID key...');
      _fcmToken = await _firebaseMessaging!.getToken(
        vapidKey:
            'BMxX8YF4KnTfRuJ5bzJSQe4GunTg8D2-BCO2xzXpzXZAo2RLdo2AY7H2HQ9iW6gOaHIsElv__EUH8ImgHnLSSGk',
      );

      if (_fcmToken != null) {
        if (kDebugMode) {
          print('[FCM Web] ✅ Token received successfully');
          print('[FCM Web] 📋 Masked token: ${_maskToken(_fcmToken)}');
          print('[FCM Web] 📏 Token length: ${_fcmToken!.length} characters');
        }
      } else {
        if (kDebugMode) {
          print('[FCM Web] ❌ Failed to get FCM token');
          print('[FCM Web] ⚠️  Possible reasons:');
          print('[FCM Web]    - Service worker not registered');
          print('[FCM Web]    - VAPID key incorrect');
          print('[FCM Web]    - Browser doesn\'t support FCM');
        }
      }

      // Listen for token refresh
      if (kDebugMode) {
        print('[FCM Web] 🔄 Setting up token refresh listener...');
      }
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('[FCM Web] 🔄 Token refreshed - registering with backend');
        }
        _fcmToken = newToken;
        _registerTokenWithBackend();
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[FCM Web] ❌ Token retrieval error: $e');
        print('[FCM Web] Stack trace: $stackTrace');
      }
    }
  }

  /// Register FCM token with Supabase backend
  Future<void> _registerTokenWithBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) {
        print('[FCM Web] ❌ No FCM token to register');
        print('[FCM Web] ⚠️  Token registration skipped');
      }
      return;
    }

    try {
      if (kDebugMode) print('[FCM Web] 🔍 Checking user authentication...');

      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('[FCM Web] ❌ User not authenticated');
          print(
              '[FCM Web] ⚠️  Token registration skipped - user must be logged in');
        }
        return;
      }

      if (kDebugMode) {
        print('[FCM Web] ✅ User authenticated: ${currentUser.id}');
        print('[FCM Web] 📧 User email: ${currentUser.email ?? 'null'}');
        print('[FCM Web] 🔍 Checking if user is anonymous...');
      }

      // Skip registration for anonymous/guest users
      final isAnonymous = currentUser.isAnonymous;
      if (isAnonymous) {
        if (kDebugMode) {
          print('[FCM Web] ⚠️  User is anonymous (guest)');
          print('[FCM Web] ❌ Skipping notification registration');
          print(
              '[FCM Web] ℹ️  Push notifications are only available for authenticated users');
        }
        return;
      }

      if (kDebugMode) {
        print('[FCM Web] ✅ User is authenticated (not anonymous)');
        print('[FCM Web] 📤 Registering FCM token with backend...');
        print('[FCM Web] 🔐 Token: ${_maskToken(_fcmToken)}');
      }

      final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      if (kDebugMode) {
        print('[FCM Web] 🌍 Timezone offset: $timezoneOffset minutes');
        print('[FCM Web] 🖥️  Platform: web');
      }

      // Call edge function to register token
      if (kDebugMode) {
        print('[FCM Web] 🚀 Calling register-fcm-token edge function...');
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
        print('[FCM Web] 📥 Response received from backend');
        print('[FCM Web] 📊 Status code: ${response.status}');
        print('[FCM Web] 📋 Response data: ${response.data}');
      }

      if (response.status == 200) {
        if (kDebugMode) {
          print('[FCM Web] ✅ Token registered successfully with backend!');
          print('[FCM Web] 🎉 User will now receive push notifications');
        }
      } else {
        if (kDebugMode) {
          print('[FCM Web] ❌ Token registration failed');
          print('[FCM Web] ⚠️  Status: ${response.status}');
          print('[FCM Web] ℹ️  Data: ${response.data}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[FCM Web] ❌ Token registration error: $e');
        print('[FCM Web] Stack trace: $stackTrace');
      }
    }
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  /// Set up listener for service worker messages (notification clicks)
  void _setupServiceWorkerMessageListener() {
    if (!kIsWeb) return;

    if (kDebugMode) {
      print('[FCM Web] Setting up service worker message listener...');
    }

    try {
      // Listen for messages from the service worker (CSP-safe using dart:html)
      if (kDebugMode) {
        print('[FCM Web] 📬 Setting up service worker message listener');
      }

      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        serviceWorker.onMessage.listen((html.MessageEvent event) {
          if (kDebugMode) {
            print('[FCM Web] 📨 Received message from service worker');
          }

          final data = event.data;
          if (data is Map && data['type'] == 'NOTIFICATION_CLICK') {
            if (kDebugMode) {
              print('[FCM Web] 🔗 Notification click detected');
            }

            final url = data['url'] as String?;
            if (url != null) {
              final uri = Uri.parse(url);
              final path = uri.path +
                  (uri.query.isNotEmpty ? '?${uri.query}' : '') +
                  (uri.hasFragment ? '#${uri.fragment}' : '');

              if (kDebugMode) {
                print('[FCM Web] 🎯 Extracted path: $path');
              }

              // Dispatch custom event for Flutter
              html.window.dispatchEvent(html.CustomEvent('notificationClick',
                  detail: {'path': path, 'data': data['data']}));
            }
          }
        });

        if (kDebugMode) {
          print('[FCM Web] ✅ Service worker message listener registered');
        }
      }

      // Listen for the custom event in Dart
      js.context['addEventListener'].apply([
        'notificationClick',
        js.allowInterop((event) {
          if (kDebugMode) {
            print('[FCM Web] 👆 Notification click event received');
          }

          try {
            final detail = js.JsObject.fromBrowserObject(event)['detail'];
            final path = detail['path'] as String;

            if (kDebugMode) {
              print('[FCM Web] 🎯 Navigating to path: $path');
            }

            // Navigate using router
            _router.go(path);
          } catch (e) {
            if (kDebugMode) {
              print('[FCM Web] ❌ Error handling notification click: $e');
            }
          }
        })
      ]);

      if (kDebugMode) {
        print(
            '[FCM Web] ✅ Service worker message listener set up successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
            '[FCM Web] ❌ Failed to set up service worker message listener: $e');
        print('[FCM Web] Stack trace: $stackTrace');
      }
    }
  }

  /// Set up listener for foreground messages
  void _setupForegroundMessageListener() {
    if (kDebugMode) {
      print('[FCM Web] Setting up foreground message listener...');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Web] ⚡⚡⚡ FOREGROUND MESSAGE RECEIVED ⚡⚡⚡');
        print('[FCM Web] Timestamp: ${DateTime.now().toIso8601String()}');
        print('[FCM Web] Message ID: ${message.messageId}');
        print('[FCM Web] From: ${message.from}');
        print('[FCM Web] Sent time: ${message.sentTime}');
        print('[FCM Web] Notification:');
        print('[FCM Web]    - Title: ${message.notification?.title ?? 'null'}');
        print('[FCM Web]    - Body: ${message.notification?.body ?? 'null'}');
        print('[FCM Web] Data: ${message.data}');
        print('[FCM Web] Data type: ${message.data['type'] ?? 'none'}');
        print('=' * 80);
      }

      // ⚠️ IMPORTANT: DO NOT show notification manually here!
      // The service worker automatically handles displaying notifications
      // for BOTH foreground and background messages.
      //
      // Showing notifications here would cause DUPLICATE notifications:
      // 1. Service worker shows notification
      // 2. This handler also shows notification → DUPLICATE!
      //
      // Instead, just emit the event for in-app handling (badges, banners, etc.)
      if (kDebugMode) {
        print('[FCM Web] 📝 Processing foreground message...');
        print('[FCM Web] ℹ️  Service worker will handle notification display');
        print('[FCM Web] ℹ️  Emitting event for in-app handling only');
      }

      // Emit notification event for in-app handling only
      // (e.g., update badge count, show in-app banner, refresh data)
      _notificationTapController.add({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        ...message.data,
      });

      // Navigation will be handled by service worker when user clicks notification
      // Don't automatically navigate when app is in foreground - let user decide
      if (kDebugMode) {
        print('[FCM Web] ✅ Event emitted for in-app updates');
        print('[FCM Web] 🔔 Service worker will show notification');
        print('[FCM Web] 👆 Navigation occurs when user clicks notification');
      }

      if (kDebugMode) {
        print('[FCM Web] ✅ ✅ ✅ FOREGROUND MESSAGE PROCESSING COMPLETE ✅ ✅ ✅');
        print('=' * 80);
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Web] ❌ ❌ ❌ FOREGROUND LISTENER ERROR ❌ ❌ ❌');
        print('[FCM Web] Error: $error');
        print('[FCM Web] Error type: ${error.runtimeType}');
        print('=' * 80);
      }
    }, onDone: () {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Web] ⚠️  FOREGROUND LISTENER CLOSED ⚠️');
        print('[FCM Web] Timestamp: ${DateTime.now().toIso8601String()}');
        print('=' * 80);
      }
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Web] 👆👆👆 NOTIFICATION TAPPED (Background) 👆👆👆');
        print('[FCM Web] Message ID: ${message.messageId}');
        print('[FCM Web] Notification data: ${message.data}');
        print('=' * 80);
      }

      if (message.data.isNotEmpty) {
        _handleMessageNavigation(message.data);
      }
    });
  }

  /// Handle navigation based on message data
  void _handleMessageNavigation(Map<String, dynamic> data) {
    // Input validation: Ensure data is not null and is a Map
    if (data.isEmpty) {
      if (kDebugMode) {
        print('[FCM Web] ⚠️  Empty notification data');
      }
      return;
    }

    // Validate notification type exists and is a string
    final type = data['type'];
    if (type == null || type is! String || type.isEmpty) {
      if (kDebugMode) {
        print('[FCM Web] ⚠️  Invalid or missing notification type');
        print('[FCM Web] Data received: $data');
      }
      return;
    }

    // Validate against known notification types
    const validTypes = {'daily_verse', 'recommended_topic'};
    if (!validTypes.contains(type)) {
      if (kDebugMode) {
        print('[FCM Web] ⚠️  Unknown notification type: $type');
        print('[FCM Web] Valid types: $validTypes');
      }
      // Navigate to home as safe fallback
      _router.go('/');
      return;
    }

    // Handle navigation based on validated type
    switch (type) {
      case 'daily_verse':
        // Navigate to home page (has daily verse)
        _router.go('/');
        if (kDebugMode) {
          print('[FCM Web] ✅ Navigating to daily verse');
        }
        break;

      case 'recommended_topic':
        // Validate topic_id if provided
        final topicId = data['topic_id'];

        if (topicId != null && topicId is String && topicId.isNotEmpty) {
          _router.go('/study-topics?topic_id=$topicId');
          if (kDebugMode) {
            print('[FCM Web] ✅ Navigating to topic: $topicId');
          }
        } else {
          _router.go('/study-topics');
          if (kDebugMode) {
            print('[FCM Web] ✅ Navigating to study topics (no specific topic)');
          }
        }
        break;
    }
  }

  // ============================================================================
  // Token Deletion
  // ============================================================================

  /// Unregister token from backend (called on logout/session expiry)
  Future<void> _unregisterTokenFromBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) {
        print('[FCM Web] No token to unregister');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('[FCM Web] 🗑️  Unregistering token from backend...');
        print('[FCM Web] Token: ${_maskToken(_fcmToken)}');
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
          print('[FCM Web] ✅ Token unregistered from backend successfully');
        }
      } else {
        if (kDebugMode) {
          print('[FCM Web] ⚠️  Token unregistration failed');
          print('[FCM Web] Status: ${response.status}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FCM Web] ❌ Error unregistering token: $e');
      }
    }
  }

  /// Delete FCM token (opt-out of notifications)
  Future<void> deleteToken() async {
    try {
      if (kDebugMode) print('[FCM Web] Deleting FCM token...');

      // First unregister from backend
      await _unregisterTokenFromBackend();

      // Then delete from Firebase
      await _firebaseMessaging?.deleteToken();
      _fcmToken = null;

      if (kDebugMode) print('[FCM Web] Token deleted successfully');
    } catch (e) {
      if (kDebugMode) print('[FCM Web] Token deletion error: $e');
    }
  }

  // ============================================================================
  // Getters
  // ============================================================================

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose resources
  void dispose() {
    _authStateSubscription?.cancel();
    _notificationTapController.close();
  }
}
