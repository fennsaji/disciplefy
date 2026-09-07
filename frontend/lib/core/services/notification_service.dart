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
import '../di/injection_container.dart';
import '../router/app_routes.dart';
import '../../features/study_generation/data/services/tts_notification_service.dart';

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

  /// In-flight initialize() call. `_isInitialized` is only set once the awaits
  /// below finish, so two concurrent callers (app startup in main.dart and the
  /// post-login call in AuthBloc) could both pass the flag check and each set
  /// up a second set of FCM listeners — making every notification tap navigate
  /// twice and stacking a duplicate screen behind the real one.
  Future<void>? _initializeInFlight;

  /// Held so listener setup can be made idempotent. Logout resets
  /// `_isInitialized` (see unregisterToken) without tearing these down, so a
  /// re-login would otherwise add another subscription each time.
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  // Stream controllers for notification events
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  // ============================================================================
  // Android Notification Channel Definitions
  // ============================================================================
  // One channel per user-visible notification category so that Android shows
  // each as a separate entry under Settings > App > Notifications.

  // These 6 channels map 1-to-1 with the 6 toggles shown in Notification Settings.
  static const _allAndroidChannels = [
    AndroidNotificationChannel(
      'daily_verse',
      'Daily Verse',
      description: 'Receive inspirational Bible verses every morning',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'recommended_topics',
      'Recommended Topics',
      description: 'Get personalized study topic suggestions',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'streak_reminders',
      'Streak Reminder',
      description: 'Get reminded to maintain your daily verse reading streak',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'streak_milestones',
      'Milestone Achievements',
      description:
          'Celebrate when you reach streak milestones (7, 30, 100, 365 days)',
    ),
    AndroidNotificationChannel(
      'streak_reset_motivation',
      'Streak Reset Motivation',
      description: 'Receive encouragement to start a new streak after a break',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'memory_verse_reminders',
      'Daily Review Reminder',
      description: 'Get reminded daily when you have verses due for review',
      importance: Importance.high,
    ),
  ];

  /// Returns the Android channel ID for a given FCM notification type.
  static String _channelIdForType(String? type) {
    switch (type) {
      case 'daily_verse':
        return 'daily_verse';
      case 'recommended_topic':
      case 'for_you':
      case 'continue_learning':
        return 'recommended_topics';
      case 'streak_reminder':
        return 'streak_reminders';
      case 'streak_milestone':
        return 'streak_milestones';
      case 'streak_lost':
        return 'streak_reset_motivation';
      default:
        return 'daily_verse'; // fallback
    }
  }

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
  Future<void> initialize() {
    if (_isInitialized) {
      if (kDebugMode) Logger.debug('[NotificationService] Already initialized');
      return Future.value();
    }
    // Join the in-flight run rather than starting a second one.
    return _initializeInFlight ??= _initialize().whenComplete(() {
      _initializeInFlight = null;
    });
  }

  Future<void> _initialize() async {
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

      // Initialize TTS playback notification channel
      if (!kIsWeb) {
        await sl<TtsNotificationService>().initialize();
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
        AndroidInitializationSettings('@drawable/ic_notification');

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

    // Explicitly register Android notification channels at startup so they
    // appear in System Settings > App > Notifications even before any
    // notification has been sent.
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        for (final channel in _allAndroidChannels) {
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    }

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
      // Check if user is authenticated
      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser == null) {
        Logger.debug(
            '[NotificationService] User not authenticated, skipping registration');
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
    _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = _firebaseMessaging?.onTokenRefresh.listen((newToken) {
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
    // Cancel first: this can run again after a logout/login cycle, and a
    // leftover subscription would deliver every tap twice.
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();

    // Foreground messages
    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tap (app in background)
    _onMessageOpenedAppSub =
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

    final channelId = _channelIdForType(message.data['type'] as String?);
    final channel = _allAndroidChannels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _allAndroidChannels.first,
    );

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
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
  /// Test seam for [_navigateFromNotification]: lets a test drive the
  /// type → route mapping without FCM, local notifications or Supabase.
  @visibleForTesting
  void navigateFromNotificationData(Map<String, dynamic> data) =>
      _navigateFromNotification(data);

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

    // Validate against known notification types.
    // Must cover every `type` the backend puts in the FCM data payload — an
    // unlisted type silently dumps the user on the home screen instead of the
    // page the notification was about.
    const validTypes = {
      'daily_verse',
      'recommended_topic',
      'continue_learning',
      'for_you',
      'streak_reminder',
      'streak_milestone',
      'streak_lost',
      'memory_verse_reminder',
      'memory_verse_overdue',
      'fellowship_meeting_reminder',
      'fellowship_meeting',
      'fellowship_meeting_cancelled',
      'fellowship_meeting_invite',
      'fellowship_new_post',
      'fellowship_new_comment',
      'fellowship_reaction',
      'fellowship_question',
      'fellowship_member_joined',
      'fellowship_daily_post',
      'fellowship_discipler_reply',
      'fellowship_discipler_activity',
      'fellowship_mention',
      'fellowship_mentor_promoted',
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
        // The daily verse lives on the home screen — there is no /daily-verse
        // route, and navigating to one produced a "Page not found" error page.
        _router.go(AppRoutes.home);
        Logger.info('[NotificationService] ✅ Navigating to daily verse (home)');
        break;

      // All three name a topic to open — 'recommended_topic' and 'for_you' a
      // fresh personalized pick, 'continue_learning' the next topic in the
      // user's most recently active learning path (backend selector picks
      // one of these two families; the client side has always been
      // identical). Generating a guide on tap, not fetching one that
      // already exists — a rethink from the old "reopen an unfinished
      // guide" behavior, whose fetch-by-id fallback chain this replaces
      // (product decision, 4 Sept 2026).
      case 'recommended_topic':
      case 'for_you':
      case 'continue_learning':
        final topicId = data['topic_id'];
        final topicTitle = data['topic_title'];
        final topicDescription = data['topic_description'];
        final language = data['language'] ?? 'en';

        if (topicTitle != null &&
            topicTitle is String &&
            topicTitle.isNotEmpty) {
          // Navigate to study guide V2 with topic information.
          // This will dynamically generate the study guide content.
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
              '/study-guide-v2?input=$encodedTitle&type=topic&language=$language&source=notification$topicIdParam$descriptionParam');
          Logger.info(
              '[NotificationService] ✅ Navigating to study guide for topic ($type): $topicTitle (ID: ${topicId ?? 'none'})');
        } else {
          _router.go('/study-topics');
          Logger.warning(
              '[NotificationService] ⚠️  No topic title provided ($type), navigating to study topics');
        }
        break;

      case 'streak_reminder':
      case 'streak_milestone':
      case 'streak_lost':
        // Streak and daily verse both live on the home screen.
        _router.go(AppRoutes.home);
        Logger.info(
            '[NotificationService] ✅ Navigating to home (streak notification)');
        break;

      case 'memory_verse_reminder':
      case 'memory_verse_overdue':
        // Land on the memory verse list, not the review screen. The review
        // screen needs a verse id, which a push cannot carry; opened without
        // one it had nowhere to go back to and 404'd on
        // '/memory-verses/practice/' (issue report, 3 Sept).
        _router.go(AppRoutes.memoryVerses);
        Logger.info('[NotificationService] ✅ Navigating to memory verse list');
        break;

      // Meetings live on the fellowship home tab. Note the invite sends
      // 'fellowship_meeting_invite'; 'meeting_invite' is only what it writes to
      // notification_logs, and is never an FCM data type.
      case 'fellowship_meeting_reminder':
      case 'fellowship_meeting':
      case 'fellowship_meeting_cancelled':
      case 'fellowship_meeting_invite':
        _goToFellowship(data, suffix: '');
        break;

      // Post activity — open the feed, where the post and its comments are.
      case 'fellowship_new_post':
      case 'fellowship_new_comment':
      case 'fellowship_reaction':
      case 'fellowship_question':
        _goToFellowship(data, suffix: '/feed');
        break;

      // Being tagged is about one thread, so deep-link to the post itself.
      case 'fellowship_mention':
        final mentionPostId = data['post_id'];
        if (mentionPostId is String && mentionPostId.isNotEmpty) {
          _goToFellowship(data, suffix: '/post/$mentionPostId');
        } else {
          _goToFellowship(data, suffix: '/feed');
        }
        break;

      // Told to the person promoted; the fellowship home shows what changed.
      case 'fellowship_mentor_promoted':
        _goToFellowship(data, suffix: '');
        break;

      // Sent to the mentor when someone joins; the member list is the point.
      case 'fellowship_member_joined':
        _goToFellowship(data, suffix: '/members');
        break;

      // The Discipler AI helper's daily study post lands in the feed.
      case 'fellowship_daily_post':
        _goToFellowship(data, suffix: '/feed');
        break;

      // A Discipler reply — deep-link straight to the thread when we have a
      // post id, else fall back to the feed.
      case 'fellowship_discipler_reply':
        final postId = data['post_id'];
        if (postId is String && postId.isNotEmpty) {
          _goToFellowship(data, suffix: '/post/$postId');
        } else {
          _goToFellowship(data, suffix: '/feed');
        }
        break;

      // Mentor-facing digest of Discipler drafts/replies/reactions awaiting
      // review.
      case 'fellowship_discipler_activity':
        _goToFellowship(data, suffix: '/discipler-activity');
        break;
    }
  }

  /// Navigates to a fellowship sub-route, falling back to the community list
  /// when the push carries no usable fellowship_id.
  void _goToFellowship(Map<String, dynamic> data, {required String suffix}) {
    final fellowshipId = data['fellowship_id'];
    if (fellowshipId is String && fellowshipId.isNotEmpty) {
      _router.go('/community/$fellowshipId$suffix');
      Logger.info(
          '[NotificationService] ✅ Navigating to fellowship: $fellowshipId$suffix');
    } else {
      _router.go(AppRoutes.community);
      Logger.warning(
          '[NotificationService] ⚠️  No fellowship_id provided, navigating to community');
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
      icon: '@drawable/ic_notification',
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
  // Token Unregistration (called on logout — BEFORE auth session is cleared)
  // ============================================================================

  /// Unregisters the current FCM token from the backend and deletes it from
  /// Firebase so this device stops receiving push notifications for the
  /// signed-out user.
  ///
  /// Must be called BEFORE the Supabase auth session is cleared (i.e. before
  /// [supabase.auth.signOut]) because the backend endpoint requires a valid
  /// auth session.
  Future<void> unregisterToken() async {
    if (kIsWeb) return; // Web platform manages its own token lifecycle

    final token = _fcmToken;

    // 1. Remove ALL tokens for this user from the backend. Using the
    //    DELETE-by-user endpoint (no body) purges the current token AND any
    //    orphaned tokens left behind by Firebase's automatic token rotation
    //    (e.g., T1 was rotated to T2 — logout would previously only remove T2).
    //    Call before signOut so the auth session is still valid.
    try {
      await _supabaseClient.functions.invoke(
        'register-fcm-token',
        method: HttpMethod.delete,
        // Omit fcmToken body → backend deletes ALL tokens for the current user
        body: {},
      );
      if (kDebugMode) {
        Logger.debug(
            '[NotificationService] ✅ All FCM tokens unregistered from backend');
      }
    } catch (e) {
      // Non-fatal — stale tokens will be auto-purged on next failed send or
      // by the nightly cleanup job.
      if (kDebugMode) {
        Logger.warning(
            '[NotificationService] ⚠️ Backend token unregister failed: $e');
      }
    }

    if (token == null) {
      if (kDebugMode) {
        Logger.debug(
            '[NotificationService] unregisterToken: no local token, skipping Firebase delete');
      }
      _isInitialized = false;
      return;
    }

    // 2. Delete from Firebase so this device gets a fresh token on next login
    try {
      await _firebaseMessaging?.deleteToken();
      if (kDebugMode) {
        Logger.debug('[NotificationService] ✅ Firebase FCM token deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        Logger.warning(
            '[NotificationService] ⚠️ Firebase token delete failed: $e');
      }
    }

    // 3. Clear local reference
    _fcmToken = null;
    _isInitialized = false;
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _notificationTapController.close();
  }
}
