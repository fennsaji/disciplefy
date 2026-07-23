// ============================================================================
// Web Notification Message Handler
// ============================================================================
// Handles FCM message reception, processing, and user interaction
// Manages foreground/background messages and navigation

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../utils/logger.dart';

/// Handles notification message processing and user interactions for web
class NotificationMessageHandlerWeb {
  final GoRouter _router;
  final FirebaseMessaging _firebaseMessaging;

  // Stream controllers for notification events
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast stream that emits notification payloads when the user taps a notification on web.
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  NotificationMessageHandlerWeb({
    required GoRouter router,
    required FirebaseMessaging firebaseMessaging,
  })  : _router = router,
        _firebaseMessaging = firebaseMessaging;

  // ============================================================================
  // Message Listener Setup
  // ============================================================================

  /// Set up listener for service worker messages (notification clicks)
  void setupServiceWorkerMessageListener() {
    if (!kIsWeb) return;

    try {
      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        serviceWorker.onMessage.listen((html.MessageEvent event) {
          final data = event.data;
          if (data is Map && data['type'] == 'NOTIFICATION_CLICK') {
            final url = data['url'] as String?;
            if (url != null) {
              final uri = Uri.parse(url);
              final path = uri.path +
                  (uri.query.isNotEmpty ? '?${uri.query}' : '') +
                  (uri.hasFragment ? '#${uri.fragment}' : '');

              Logger.debug('[FCM] 🔗 Notification click → path: $path');

              // Dispatch custom event for Flutter
              html.window.dispatchEvent(html.CustomEvent('notificationClick',
                  detail: {'path': path, 'data': data['data']}));
            }
          }
        });
      }

      // Listen for the custom event in Dart. The event is dispatched above via
      // html.CustomEvent, so its detail comes back as a plain Dart Map — no JS
      // interop needed to read it.
      html.window.on['notificationClick'].listen((html.Event event) {
        try {
          final detail = (event as html.CustomEvent).detail;
          final path = (detail as Map)['path'] as String;
          Logger.debug('[FCM] 👆 Navigating to: $path');
          _router.go(path);
        } catch (e) {
          Logger.error('[FCM] ❌ Error handling notification click: $e');
        }
      });

      Logger.debug('[FCM] ✅ Service worker message listener set up');
    } catch (e, stackTrace) {
      Logger.error('[FCM] ❌ Failed to set up service worker listener: $e',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Set up listener for foreground messages
  void setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        Logger.debug(
            '[FCM] ⚡ Foreground message received | type=${message.data['type'] ?? 'none'} | title=${message.notification?.title}');
      }

      // ⚠️ IMPORTANT: Service worker onBackgroundMessage ONLY fires when app is BACKGROUND!
      // For FOREGROUND messages, we MUST show notifications manually using Web Notifications API
      _showForegroundNotification(message);

      // Emit notification event for in-app handling
      _notificationTapController.add({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        ...message.data,
      });
    }, onError: (error) {
      Logger.error('[FCM] ❌ Foreground listener error: $error');
    }, onDone: () {
      Logger.warning('[FCM] ⚠️ Foreground listener closed');
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Logger.info(
          '[FCM] 👆 Notification tapped (background) | type=${message.data['type']}');

      if (message.data.isNotEmpty) {
        _handleMessageNavigation(message.data);
      }
    });
  }

  // ============================================================================
  // Notification Display
  // ============================================================================

  /// Show browser notification for foreground messages
  /// Uses Web Notifications API (html.Notification) directly
  void _showForegroundNotification(RemoteMessage message) {
    try {
      if (!kIsWeb) return;

      final title = message.notification?.title ?? '📖 Disciplefy';
      final body = message.notification?.body ?? 'You have a new notification';
      final icon =
          message.notification?.android?.smallIcon ?? '/icons/Icon-192.png';

      // Create notification using Web Notifications API
      final notification = html.Notification(
        title,
        body: body,
        icon: icon,
        tag: message.data['type'] ??
            'default', // Replaces notifications with same tag
      );

      // Handle notification click
      notification.onClick.listen((_) {
        notification.close();
        if (message.data.isNotEmpty) {
          _handleMessageNavigation(message.data);
        }
      });

      // Auto-close after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        try {
          notification.close();
        } catch (e) {
          // Notification might already be closed by user
        }
      });
    } catch (e, stackTrace) {
      Logger.error('[FCM] ❌ Error showing foreground notification: $e',
          error: e, stackTrace: stackTrace);
    }
  }

  // ============================================================================
  // Navigation Handling
  // ============================================================================

  /// Handle navigation based on message data
  void _handleMessageNavigation(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type'];
    if (type == null || type is! String || type.isEmpty) {
      Logger.warning(
          '[FCM] ⚠️ Invalid or missing notification type | data: $data');
      return;
    }

    const validTypes = {
      'daily_verse',
      'recommended_topic',
      'continue_learning',
      'for_you'
    };
    if (!validTypes.contains(type)) {
      Logger.warning('[FCM] ⚠️ Unknown notification type: $type');
      _router.go('/');
      return;
    }

    switch (type) {
      case 'daily_verse':
        _router.go('/');
        Logger.debug('[FCM] ✅ Navigate → daily verse (home)');
        break;

      case 'recommended_topic':
        final topicId = data['topic_id'];
        final topicTitle = data['topic_title'];
        final language = data['language'] ?? 'en';

        if (topicTitle != null &&
            topicTitle is String &&
            topicTitle.isNotEmpty) {
          final encodedTitle = Uri.encodeComponent(topicTitle);
          final topicIdParam =
              (topicId != null && topicId is String && topicId.isNotEmpty)
                  ? '&topic_id=$topicId'
                  : '';

          _router.go(
              '/study-guide-v2?input=$encodedTitle&type=topic&language=$language&source=notification$topicIdParam');
          Logger.debug('[FCM] ✅ Navigate → recommended topic: $topicTitle');
        } else {
          _router.go('/study-topics');
          Logger.warning('[FCM] ⚠️ No topic title, navigating to study topics');
        }
        break;

      case 'continue_learning':
        final guideId = data['guide_id'];
        final topicTitle = data['topic_title'];

        if (guideId != null && guideId is String && guideId.isNotEmpty) {
          _router.go('/study-guide/$guideId');
          Logger.debug(
              '[FCM] ✅ Navigate → continue learning: $guideId (${topicTitle ?? 'unknown'})');
        } else {
          _router.go('/study-topics');
          Logger.warning('[FCM] ⚠️ No guide ID, navigating to study topics');
        }
        break;

      case 'for_you':
        final topicId = data['topic_id'];
        final topicTitle = data['topic_title'];
        final topicDescription = data['topic_description'];
        final language = data['language'] ?? 'en';

        if (topicTitle != null &&
            topicTitle is String &&
            topicTitle.isNotEmpty) {
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
          Logger.debug('[FCM] ✅ Navigate → for_you topic: $topicTitle');
        } else {
          _router.go('/study-topics');
          Logger.warning(
              '[FCM] ⚠️ No for_you topic title, navigating to study topics');
        }
        break;
    }
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose resources and close stream controllers
  void dispose() {
    _notificationTapController.close();
  }
}
