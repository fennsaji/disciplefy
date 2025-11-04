// ============================================================================
// Web Notification Message Handler
// ============================================================================
// Handles FCM message reception, processing, and user interaction
// Manages foreground/background messages and navigation

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Handles notification message processing and user interactions for web
class NotificationMessageHandlerWeb {
  final GoRouter _router;
  final FirebaseMessaging _firebaseMessaging;

  // Stream controllers for notification events
  final _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
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

    if (kDebugMode) {
      print('[FCM Message] Setting up service worker message listener...');
    }

    try {
      // Listen for messages from the service worker (CSP-safe using dart:html)
      if (kDebugMode) {
        print('[FCM Message] 📬 Setting up service worker message listener');
      }

      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        serviceWorker.onMessage.listen((html.MessageEvent event) {
          if (kDebugMode) {
            print('[FCM Message] 📨 Received message from service worker');
          }

          final data = event.data;
          if (data is Map && data['type'] == 'NOTIFICATION_CLICK') {
            if (kDebugMode) {
              print('[FCM Message] 🔗 Notification click detected');
            }

            final url = data['url'] as String?;
            if (url != null) {
              final uri = Uri.parse(url);
              final path = uri.path +
                  (uri.query.isNotEmpty ? '?${uri.query}' : '') +
                  (uri.hasFragment ? '#${uri.fragment}' : '');

              if (kDebugMode) {
                print('[FCM Message] 🎯 Extracted path: $path');
              }

              // Dispatch custom event for Flutter
              html.window.dispatchEvent(html.CustomEvent('notificationClick',
                  detail: {'path': path, 'data': data['data']}));
            }
          }
        });

        if (kDebugMode) {
          print('[FCM Message] ✅ Service worker message listener registered');
        }
      }

      // Listen for the custom event in Dart
      js.context['addEventListener'].apply([
        'notificationClick',
        js.allowInterop((event) {
          if (kDebugMode) {
            print('[FCM Message] 👆 Notification click event received');
          }

          try {
            final detail = js.JsObject.fromBrowserObject(event)['detail'];
            final path = detail['path'] as String;

            if (kDebugMode) {
              print('[FCM Message] 🎯 Navigating to path: $path');
            }

            // Navigate using router
            _router.go(path);
          } catch (e) {
            if (kDebugMode) {
              print('[FCM Message] ❌ Error handling notification click: $e');
            }
          }
        })
      ]);

      if (kDebugMode) {
        print(
            '[FCM Message] ✅ Service worker message listener set up successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print(
            '[FCM Message] ❌ Failed to set up service worker message listener: $e');
        print('[FCM Message] Stack trace: $stackTrace');
      }
    }
  }

  /// Set up listener for foreground messages
  void setupForegroundMessageListener() {
    if (kDebugMode) {
      print('[FCM Message] Setting up foreground message listener...');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Message] ⚡⚡⚡ FOREGROUND MESSAGE RECEIVED ⚡⚡⚡');
        print('[FCM Message] Timestamp: ${DateTime.now().toIso8601String()}');
        print('[FCM Message] Message ID: ${message.messageId}');
        print('[FCM Message] From: ${message.from}');
        print('[FCM Message] Sent time: ${message.sentTime}');
        print('[FCM Message] Notification:');
        print(
            '[FCM Message]    - Title: ${message.notification?.title ?? 'null'}');
        print(
            '[FCM Message]    - Body: ${message.notification?.body ?? 'null'}');
        print('[FCM Message] Data: ${message.data}');
        print('[FCM Message] Data type: ${message.data['type'] ?? 'none'}');
        print('=' * 80);
      }

      // ⚠️ IMPORTANT: Service worker onBackgroundMessage ONLY fires when app is BACKGROUND!
      // For FOREGROUND messages, we MUST show notifications manually using Web Notifications API
      // Otherwise, users won't see notifications when the app is open
      if (kDebugMode) {
        print('[FCM Message] 📝 Processing foreground message...');
        print(
            '[FCM Message] 🔔 Showing browser notification (app is in foreground)');
      }

      // Show browser notification for foreground messages
      _showForegroundNotification(message);

      // Emit notification event for in-app handling
      // (e.g., update badge count, show in-app banner, refresh data)
      _notificationTapController.add({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        ...message.data,
      });

      if (kDebugMode) {
        print(
            '[FCM Message] ✅ ✅ ✅ FOREGROUND MESSAGE PROCESSING COMPLETE ✅ ✅ ✅');
        print('=' * 80);
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Message] ❌ ❌ ❌ FOREGROUND LISTENER ERROR ❌ ❌ ❌');
        print('[FCM Message] Error: $error');
        print('[FCM Message] Error type: ${error.runtimeType}');
        print('=' * 80);
      }
    }, onDone: () {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Message] ⚠️  FOREGROUND LISTENER CLOSED ⚠️');
        print('[FCM Message] Timestamp: ${DateTime.now().toIso8601String()}');
        print('=' * 80);
      }
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('=' * 80);
        print('[FCM Message] 👆👆👆 NOTIFICATION TAPPED (Background) 👆👆👆');
        print('[FCM Message] Message ID: ${message.messageId}');
        print('[FCM Message] Notification data: ${message.data}');
        print('=' * 80);
      }

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

      // Extract notification data
      final title = message.notification?.title ?? '📖 Disciplefy';
      final body = message.notification?.body ?? 'You have a new notification';
      final icon =
          message.notification?.android?.smallIcon ?? '/icons/Icon-192.png';

      if (kDebugMode) {
        print('[FCM Message] 🔔 Creating browser notification...');
        print('[FCM Message]    Title: $title');
        print('[FCM Message]    Body: $body');
        print('[FCM Message]    Icon: $icon');
      }

      // Create notification using Web Notifications API
      // This shows a native browser notification
      final notification = html.Notification(
        title,
        body: body,
        icon: icon,
        tag: message.data['type'] ??
            'default', // Replaces notifications with same tag
      );

      // Handle notification click
      notification.onClick.listen((_) {
        if (kDebugMode) {
          print('[FCM Message] 👆 Foreground notification clicked');
        }

        // Close the notification
        notification.close();

        // Navigate based on notification data
        if (message.data.isNotEmpty) {
          _handleMessageNavigation(message.data);
        }
      });

      // Auto-close after 10 seconds (browser default)
      Future.delayed(const Duration(seconds: 10), () {
        try {
          notification.close();
        } catch (e) {
          // Notification might already be closed by user
        }
      });

      if (kDebugMode) {
        print('[FCM Message] ✅ Browser notification created successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[FCM Message] ❌ Error showing foreground notification: $e');
        print('[FCM Message] Stack trace: $stackTrace');
      }
    }
  }

  // ============================================================================
  // Navigation Handling
  // ============================================================================

  /// Handle navigation based on message data
  void _handleMessageNavigation(Map<String, dynamic> data) {
    // Input validation: Ensure data is not null and is a Map
    if (data.isEmpty) {
      if (kDebugMode) {
        print('[FCM Message] ⚠️  Empty notification data');
      }
      return;
    }

    // Validate notification type exists and is a string
    final type = data['type'];
    if (type == null || type is! String || type.isEmpty) {
      if (kDebugMode) {
        print('[FCM Message] ⚠️  Invalid or missing notification type');
        print('[FCM Message] Data received: $data');
      }
      return;
    }

    // Validate against known notification types
    const validTypes = {'daily_verse', 'recommended_topic'};
    if (!validTypes.contains(type)) {
      if (kDebugMode) {
        print('[FCM Message] ⚠️  Unknown notification type: $type');
        print('[FCM Message] Valid types: $validTypes');
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
          print('[FCM Message] ✅ Navigating to daily verse');
        }
        break;

      case 'recommended_topic':
        // Validate topic_id if provided
        final topicId = data['topic_id'];

        if (topicId != null && topicId is String && topicId.isNotEmpty) {
          _router.go('/study-topics?topic_id=$topicId');
          if (kDebugMode) {
            print('[FCM Message] ✅ Navigating to topic: $topicId');
          }
        } else {
          _router.go('/study-topics');
          if (kDebugMode) {
            print(
                '[FCM Message] ✅ Navigating to study topics (no specific topic)');
          }
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
