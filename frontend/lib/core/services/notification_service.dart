// ============================================================================
// Notification Service
// ============================================================================
// Manages Firebase Cloud Messaging integration for push notifications
// Handles token registration, notification display, and deep linking

import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:go_router/go_router.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('[FCM Background] Message received: ${message.messageId}');
    print('[FCM Background] Notification: ${message.notification?.title}');
  }
}

class NotificationService {
  final SupabaseClient _supabaseClient;
  final GoRouter _router;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;
  bool _isInitialized = false;

  // Stream controllers for notification events
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  NotificationService({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  })  : _supabaseClient = supabaseClient,
        _router = router;

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize notification service
  /// Call this during app startup after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) print('[NotificationService] Already initialized');
      return;
    }

    try {
      if (kDebugMode) print('[NotificationService] Initializing...');

      // Initialize timezone database for scheduled notifications
      tz.initializeTimeZones();

      // Initialize Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      final permissionGranted = await requestPermissions();

      if (permissionGranted) {
        // Get FCM token
        await _getFCMToken();

        // Register token with backend
        if (_fcmToken != null) {
          await _registerTokenWithBackend();
        }

        // Setup notification listeners
        _setupNotificationListeners();

        // Handle notification that opened the app from terminated state
        await _handleInitialMessage();
      }

      _isInitialized = true;
      if (kDebugMode) print('[NotificationService] ✅ Initialization complete');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[NotificationService] ❌ Initialization error: $e');
        print('[NotificationService] Stack trace: $stackTrace');
      }
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    if (kDebugMode) {
      print('[NotificationService] Local notifications initialized');
    }
  }

  // ============================================================================
  // Permissions
  // ============================================================================

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) {
        // Web permissions (using default values)
        final messagingPermission =
            await _firebaseMessaging?.requestPermission();

        final granted = messagingPermission?.authorizationStatus ==
            AuthorizationStatus.authorized;
        if (kDebugMode) {
          print('[NotificationService] Web permissions: $granted');
        }
        return granted;
      } else if (Platform.isIOS) {
        // iOS permissions
        final messagingPermission =
            await _firebaseMessaging?.requestPermission();

        final granted = messagingPermission?.authorizationStatus ==
            AuthorizationStatus.authorized;
        if (kDebugMode) {
          print('[NotificationService] iOS permissions: $granted');
        }
        return granted;
      } else {
        // Android 13+ permissions
        if (Platform.isAndroid) {
          final status = await Permission.notification.request();
          final granted = status.isGranted;
          if (kDebugMode) {
            print('[NotificationService] Android permissions: $granted');
          }
          return granted;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('[NotificationService] Permission error: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      if (kIsWeb) {
        final settings = await _firebaseMessaging?.getNotificationSettings();
        return settings?.authorizationStatus == AuthorizationStatus.authorized;
      } else if (Platform.isIOS) {
        final settings = await _firebaseMessaging?.getNotificationSettings();
        return settings?.authorizationStatus == AuthorizationStatus.authorized;
      } else if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Check permissions error: $e');
      }
      return false;
    }
  }

  // ============================================================================
  // FCM Token Management
  // ============================================================================

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging?.getToken();
      if (kDebugMode) print('[NotificationService] FCM Token: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      if (kDebugMode) print('[NotificationService] Get token error: $e');
      return null;
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) print('[NotificationService] No FCM token to register');
      return;
    }

    try {
      // Check if user is authenticated and not anonymous
      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print(
              '[NotificationService] User not authenticated, skipping registration');
        }
        return;
      }

      // Skip registration for anonymous/guest users
      final isAnonymous = currentUser.isAnonymous;
      if (isAnonymous) {
        if (kDebugMode) {
          print(
              '[NotificationService] ⚠️  User is anonymous (guest), skipping notification registration');
          print(
              '[NotificationService] Push notifications are only available for authenticated users');
        }
        return;
      }

      // Detect platform
      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else {
        platform = 'unknown';
      }

      // Get timezone offset in minutes
      final timezoneOffset = DateTime.now().timeZoneOffset.inMinutes;

      if (kDebugMode) {
        print('[NotificationService] Registering token...');
        print('[NotificationService] Platform: $platform');
        print('[NotificationService] Timezone offset: $timezoneOffset minutes');
      }

      // Call backend edge function
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        body: {
          'fcmToken': _fcmToken,
          'platform': platform,
          'timezoneOffsetMinutes': timezoneOffset,
        },
      );

      if (response.status == 200) {
        if (kDebugMode) {
          print('[NotificationService] ✅ Token registered successfully');
        }
      } else {
        if (kDebugMode) {
          print('[NotificationService] ❌ Token registration failed');
          print('[NotificationService] Status: ${response.status}');
          print('[NotificationService] Data: ${response.data}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Token registration error: $e');
      }
    }
  }

  /// Handle token refresh
  void _setupTokenRefreshListener() {
    _firebaseMessaging?.onTokenRefresh.listen((newToken) {
      if (kDebugMode) print('[NotificationService] Token refreshed: $newToken');
      _fcmToken = newToken;
      _registerTokenWithBackend();
    });
  }

  // ============================================================================
  // Notification Listeners
  // ============================================================================

  /// Setup notification listeners for all states
  void _setupNotificationListeners() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Token refresh
    _setupTokenRefreshListener();

    if (kDebugMode) {
      print('[NotificationService] Notification listeners set up');
    }
  }

  /// Handle notification when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('[NotificationService] Foreground message received');
      print('[NotificationService] Title: ${message.notification?.title}');
      print('[NotificationService] Body: ${message.notification?.body}');
    }

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle notification tap (from background or terminated state)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('[NotificationService] Notification tapped');
      print('[NotificationService] Data: ${message.data}');
    }

    // Emit notification tap event
    _notificationTapController.add(message.data);

    // Navigate based on notification type
    _navigateFromNotification(message.data);
  }

  /// Handle initial message (app opened from terminated state)
  Future<void> _handleInitialMessage() async {
    final initialMessage = await _firebaseMessaging?.getInitialMessage();

    if (initialMessage != null) {
      if (kDebugMode) {
        print('[NotificationService] App opened from notification');
        print('[NotificationService] Data: ${initialMessage.data}');
      }

      // Delay navigation to ensure app is fully initialized
      await Future.delayed(const Duration(seconds: 1));
      _navigateFromNotification(initialMessage.data);
    }
  }

  // ============================================================================
  // Local Notification Display
  // ============================================================================

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_notifications',
      'Daily Notifications',
      channelDescription: 'Daily verse and study topic notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );

    if (kDebugMode) print('[NotificationService] Local notification displayed');
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('[NotificationService] Local notification tapped');
      print('[NotificationService] Payload: ${response.payload}');
    }

    // Parse payload and navigate
    // Note: payload is string representation, would need proper parsing
    // For now, we'll rely on FCM notification taps which have proper data
  }

  // ============================================================================
  // Navigation & Deep Linking
  // ============================================================================

  /// Navigate based on notification type
  void _navigateFromNotification(Map<String, dynamic> data) {
    // Input validation: Ensure data is not null and is a Map
    if (data.isEmpty) {
      if (kDebugMode) {
        print('[NotificationService] ⚠️  Empty notification data');
      }
      return;
    }

    // Validate notification type exists and is a string
    final type = data['type'];
    if (type == null || type is! String || type.isEmpty) {
      if (kDebugMode) {
        print('[NotificationService] ⚠️  Invalid or missing notification type');
        print('[NotificationService] Data received: $data');
      }
      return;
    }

    // Validate against known notification types
    const validTypes = {'daily_verse', 'recommended_topic'};
    if (!validTypes.contains(type)) {
      if (kDebugMode) {
        print('[NotificationService] ⚠️  Unknown notification type: $type');
        print('[NotificationService] Valid types: $validTypes');
      }
      // Navigate to home as safe fallback
      _router.go('/');
      return;
    }

    // Handle navigation based on validated type
    switch (type) {
      case 'daily_verse':
        // Navigate to daily verse screen
        _router.go('/daily-verse');
        if (kDebugMode) {
          print('[NotificationService] ✅ Navigating to daily verse');
        }
        break;

      case 'recommended_topic':
        // Validate topic_id if provided
        final topicId = data['topic_id'];

        if (topicId != null && topicId is String && topicId.isNotEmpty) {
          _router.go('/study-topics?topic_id=$topicId');
          if (kDebugMode) {
            print('[NotificationService] ✅ Navigating to topic: $topicId');
          }
        } else {
          _router.go('/study-topics');
          if (kDebugMode) {
            print(
                '[NotificationService] ✅ Navigating to study topics (no specific topic)');
          }
        }
        break;
    }
  }

  // ============================================================================
  // Preference Management
  // ============================================================================

  /// Update notification preferences
  Future<bool> updatePreferences({
    bool? dailyVerseEnabled,
    bool? recommendedTopicEnabled,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.put,
        body: {
          if (dailyVerseEnabled != null) 'dailyVerseEnabled': dailyVerseEnabled,
          if (recommendedTopicEnabled != null)
            'recommendedTopicEnabled': recommendedTopicEnabled,
        },
      );

      if (response.status == 200) {
        if (kDebugMode) print('[NotificationService] ✅ Preferences updated');
        return true;
      } else {
        if (kDebugMode) {
          print('[NotificationService] ❌ Preferences update failed');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Update preferences error: $e');
      }
      return false;
    }
  }

  /// Get current notification preferences
  Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.get,
      );

      if (response.status == 200 && response.data != null) {
        return response.data['preferences'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('[NotificationService] Get preferences error: $e');
      return null;
    }
  }

  // ============================================================================
  // Testing & Utilities
  // ============================================================================

  /// Send test notification (for testing purposes)
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_notifications',
      'Daily Notifications',
      channelDescription: 'Daily verse and study topic notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique notification ID
      '📖 Test Notification',
      'This is a test notification from Disciplefy',
      details,
      payload: {'type': 'test'}.toString(),
    );
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  // ============================================================================
  // Cleanup
  // ============================================================================

  void dispose() {
    _notificationTapController.close();
  }
}
