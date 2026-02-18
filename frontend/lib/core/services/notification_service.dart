// ============================================================================
// Notification Service
// ============================================================================
// Manages Firebase Cloud Messaging integration for push notifications
// Handles token registration, notification display, and deep linking

import 'dart:async';
import 'dart:convert';
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
import '../utils/logger.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    Logger.debug('[FCM Background] Message received: ${message.messageId}');
    Logger.debug(
        '[FCM Background] Notification: ${message.notification?.title}');
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
      if (kDebugMode) Logger.debug('[NotificationService] Already initialized');
      return;
    }

    try {
      if (kDebugMode) Logger.debug('[NotificationService] Initializing...');

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
      if (kDebugMode) {
        Logger.debug('[NotificationService] ✅ Initialization complete');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        Logger.error('[NotificationService] ❌ Initialization error: $e');
        Logger.debug('[NotificationService] Stack trace: $stackTrace');
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

    Logger.info('[NotificationService] Local notifications initialized');
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
        Logger.debug('[NotificationService] Web permissions: $granted');
        return granted;
      } else if (Platform.isIOS) {
        // iOS permissions
        final messagingPermission =
            await _firebaseMessaging?.requestPermission();

        final granted = messagingPermission?.authorizationStatus ==
            AuthorizationStatus.authorized;
        Logger.debug('[NotificationService] iOS permissions: $granted');
        return granted;
      } else {
        // Android 13+ permissions
        if (Platform.isAndroid) {
          final status = await Permission.notification.request();
          final granted = status.isGranted;
          Logger.debug('[NotificationService] Android permissions: $granted');
          return granted;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        Logger.debug('[NotificationService] Permission error: $e');
      }
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      if (kIsWeb) {
        // For web, try to initialize Firebase Messaging if not already done
        // This ensures we can check permissions even if initialize() wasn't called
        if (_firebaseMessaging == null) {
          try {
            _firebaseMessaging = FirebaseMessaging.instance;
          } catch (e) {
            Logger.debug(
                '[NotificationService] Could not initialize Firebase Messaging: $e');
            return false;
          }
        }

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
      Logger.error('[NotificationService] Check permissions error: $e');
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
      if (kDebugMode) {
        Logger.debug('[NotificationService] FCM Token: $_fcmToken');
      }
      return _fcmToken;
    } catch (e) {
      if (kDebugMode) Logger.debug('[NotificationService] Get token error: $e');
      return null;
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend() async {
    if (_fcmToken == null) {
      if (kDebugMode) {
        Logger.debug('[NotificationService] No FCM token to register');
      }
      return;
    }

    try {
      // Check if user is authenticated and not anonymous
      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        Logger.debug(
            '[NotificationService] User not authenticated, skipping registration');
        return;
      }

      // Skip registration for anonymous/guest users
      final isAnonymous = currentUser.isAnonymous;
      if (isAnonymous) {
        if (kDebugMode) {
          Logger.warning(
              '[NotificationService] ⚠️  User is anonymous (guest), skipping notification registration');
          Logger.debug(
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
        Logger.debug('[NotificationService] Registering token...');
        Logger.debug('[NotificationService] Platform: $platform');
        Logger.debug(
            '[NotificationService] Timezone offset: $timezoneOffset minutes');
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
        Logger.error('[NotificationService] ✅ Token registered successfully');
      } else {
        if (kDebugMode) {
          Logger.debug('[NotificationService] ❌ Token registration failed');
          Logger.debug('[NotificationService] Status: ${response.status}');
          Logger.debug('[NotificationService] Data: ${response.data}');
        }
      }
    } catch (e) {
      Logger.error('[NotificationService] Token registration error: $e');
    }
  }

  /// Handle token refresh
  void _setupTokenRefreshListener() {
    _firebaseMessaging?.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        Logger.debug('[NotificationService] Token refreshed: $newToken');
      }
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

    Logger.debug('[NotificationService] Notification listeners set up');
  }

  /// Handle notification when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      Logger.debug('[NotificationService] Foreground message received');
      Logger.debug(
          '[NotificationService] Title: ${message.notification?.title}');
      Logger.debug('[NotificationService] Body: ${message.notification?.body}');
    }

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle notification tap (from background or terminated state)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      Logger.debug('[NotificationService] Notification tapped');
      Logger.debug('[NotificationService] Data: ${message.data}');
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
        Logger.debug('[NotificationService] App opened from notification');
        Logger.debug('[NotificationService] Data: ${initialMessage.data}');
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
      payload: jsonEncode(message.data),
    );

    if (kDebugMode) {
      Logger.debug('[NotificationService] Local notification displayed');
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      Logger.debug('[NotificationService] Local notification tapped');
      Logger.debug('[NotificationService] Payload: ${response.payload}');
    }

    // Parse payload and navigate
    if (response.payload == null || response.payload!.isEmpty) {
      Logger.warning(
          '[NotificationService] ⚠️  Empty payload, cannot navigate');
      return;
    }

    try {
      // Decode JSON payload
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;

      Logger.debug('[NotificationService] Decoded payload: $data');

      // Emit notification tap event
      _notificationTapController.add(data);

      // Navigate based on notification data
      _navigateFromNotification(data);
    } catch (e) {
      if (kDebugMode) {
        Logger.error('[NotificationService] ❌ Failed to parse payload: $e');
        Logger.debug('[NotificationService] Raw payload: ${response.payload}');
      }
    }
  }

  // ============================================================================
  // Navigation & Deep Linking
  // ============================================================================

  /// Navigate based on notification type
  void _navigateFromNotification(Map<String, dynamic> data) {
    // Input validation: Ensure data is not null and is a Map
    if (data.isEmpty) {
      Logger.warning('[NotificationService] ⚠️  Empty notification data');
      return;
    }

    // Validate notification type exists and is a string
    final type = data['type'];
    if (type == null || type is! String || type.isEmpty) {
      if (kDebugMode) {
        Logger.warning(
            '[NotificationService] ⚠️  Invalid or missing notification type');
        Logger.debug('[NotificationService] Data received: $data');
      }
      return;
    }

    // Validate against known notification types
    const validTypes = {
      'daily_verse',
      'recommended_topic',
      'continue_learning',
      'for_you'
    };
    if (!validTypes.contains(type)) {
      if (kDebugMode) {
        Logger.warning(
            '[NotificationService] ⚠️  Unknown notification type: $type');
        Logger.debug('[NotificationService] Valid types: $validTypes');
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
        Logger.info('[NotificationService] ✅ Navigating to daily verse');
        break;

      case 'recommended_topic':
        // Extract topic information from notification data
        // Priority: topic_id (for tracking) + topic_title + topic_description (for generation)
        final topicId = data['topic_id'];
        final topicTitle = data['topic_title'];
        final topicDescription = data['topic_description'];
        final language = data['language'] ?? 'en';

        if (topicTitle != null &&
            topicTitle is String &&
            topicTitle.isNotEmpty) {
          // Navigate to study guide V2 with topic information
          // This will dynamically generate the study guide content
          final encodedTitle = Uri.encodeComponent(topicTitle);

          // Include topic_id if available for tracking/future features
          final topicIdParam =
              (topicId != null && topicId is String && topicId.isNotEmpty)
                  ? '&topic_id=$topicId'
                  : '';

          // Include topic_description if available for richer context in study guide generation
          final descriptionParam = (topicDescription != null &&
                  topicDescription is String &&
                  topicDescription.isNotEmpty)
              ? '&description=${Uri.encodeComponent(topicDescription)}'
              : '';

          _router.go(
              '/study-guide-v2?input=$encodedTitle&type=topic&language=$language&source=notification$topicIdParam$descriptionParam');
          Logger.info(
              '[NotificationService] ✅ Navigating to study guide for topic: $topicTitle (ID: ${topicId ?? 'none'})');
        } else {
          // Fallback to study topics page if no topic title provided
          _router.go('/study-topics');
          Logger.warning(
              '[NotificationService] ⚠️  No topic title provided, navigating to study topics');
        }
        break;

      case 'continue_learning':
        // Continue Learning: Navigate to existing incomplete guide
        final guideId = data['guide_id'];
        final topicTitle = data['topic_title']; // For debug logging

        if (guideId != null && guideId is String && guideId.isNotEmpty) {
          // Navigate to the specific incomplete study guide
          _router.go('/study-guide/$guideId');
          Logger.info(
              '[NotificationService] ✅ Navigating to Continue Learning guide: $guideId (${topicTitle ?? 'unknown'})');
        } else {
          // Fallback to study topics page if no guide ID provided
          _router.go('/study-topics');
          Logger.warning(
              '[NotificationService] ⚠️  No guide ID provided, navigating to study topics');
        }
        break;

      case 'for_you':
        // For You: Same as recommended_topic, personalized topic recommendation
        final topicId = data['topic_id'];
        final topicTitle = data['topic_title'];
        final topicDescription = data['topic_description'];
        final language = data['language'] ?? 'en';

        if (topicTitle != null &&
            topicTitle is String &&
            topicTitle.isNotEmpty) {
          // Navigate to study guide V2 with topic information
          final encodedTitle = Uri.encodeComponent(topicTitle);

          final topicIdParam =
              (topicId != null && topicId is String && topicId.isNotEmpty)
                  ? '&topic_id=$topicId'
                  : '';

          final descriptionParam = (topicDescription != null &&
                  topicDescription is String &&
                  topicDescription.isNotEmpty)
              ? '&description=${Uri.encodeComponent(topicDescription)}'
              : '';

          _router.go(
              '/study-guide-v2?input=$encodedTitle&type=topic&language=$language&source=for_you_notification$topicIdParam$descriptionParam');
          Logger.info(
              '[NotificationService] ✅ Navigating to For You topic: $topicTitle (ID: ${topicId ?? 'none'})');
        } else {
          // Fallback to study topics page if no topic title provided
          _router.go('/study-topics');
          Logger.warning(
              '[NotificationService] ⚠️  No For You topic title provided, navigating to study topics');
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
        if (kDebugMode) {
          Logger.debug('[NotificationService] ✅ Preferences updated');
        }
        return true;
      } else {
        Logger.error('[NotificationService] ❌ Preferences update failed');
        return false;
      }
    } catch (e) {
      Logger.error('[NotificationService] Update preferences error: $e');
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
      if (kDebugMode) {
        Logger.debug('[NotificationService] Get preferences error: $e');
      }
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
      payload: jsonEncode({'type': 'test'}),
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
