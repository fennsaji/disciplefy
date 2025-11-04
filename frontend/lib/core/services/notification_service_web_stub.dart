// Stub file for non-web platforms
// This file is used when building for mobile/desktop platforms
// The actual web implementation is in notification_service_web.dart

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub implementation of [NotificationServiceWeb] for non-web platforms.
///
/// This stub provides API parity with the actual web implementation but throws
/// [UnimplementedError] for all operations. It exists to satisfy conditional
/// imports and ensure type safety across platforms.
///
/// **Platform Limitation:**
/// This class should never be instantiated on mobile or desktop platforms.
/// The actual implementation is in `notification_service_web.dart` and is only
/// available when building for web (dart:html available).
///
/// **Usage:**
/// ```dart
/// import 'core/services/notification_service_web_stub.dart'
///     if (dart.library.html) 'core/services/notification_service_web.dart';
/// ```
///
/// **Note:**
/// This stub must maintain API parity with `notification_service_web.dart` to
/// ensure type safety across conditional imports. Any changes to the web
/// implementation's public API must be reflected here.
class NotificationServiceWeb {
  /// Creates a new instance of [NotificationServiceWeb].
  ///
  /// **Platform Limitation:**
  /// This constructor always throws [UnimplementedError] on non-web platforms.
  ///
  /// **Parameters:**
  /// - [supabaseClient]: Supabase client for backend communication (unused in stub)
  /// - [router]: GoRouter instance for navigation (unused in stub)
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown, as this service is web-only
  ///
  /// **Example:**
  /// ```dart
  /// // This will throw on mobile/desktop:
  /// final service = NotificationServiceWeb(
  ///   supabaseClient: Supabase.instance.client,
  ///   router: router,
  /// );
  /// ```
  NotificationServiceWeb({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  }) {
    throw UnimplementedError(
      'NotificationServiceWeb is only available on web platform',
    );
  }

  /// Initializes the Firebase Cloud Messaging service for web.
  ///
  /// On web platforms, this method:
  /// - Requests notification permissions from the browser
  /// - Obtains an FCM token for push notifications
  /// - Sets up foreground and background message listeners
  /// - Registers the FCM token with the Supabase backend
  /// - Configures auth state monitoring for token management
  ///
  /// **Platform Limitation:**
  /// This method always throws [UnimplementedError] on non-web platforms.
  /// Use platform-specific notification services for mobile/desktop.
  ///
  /// **Returns:**
  /// A [Future] that completes when initialization finishes (web only).
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: initializes FCM and requests permissions
  /// // On mobile/desktop: throws UnimplementedError
  /// await notificationService.initialize();
  /// ```
  Future<void> initialize() async {
    throw UnimplementedError(
      'NotificationServiceWeb.initialize is only available on web platform',
    );
  }

  /// Requests notification permissions from the browser.
  ///
  /// On web platforms, this method prompts the user to grant notification
  /// permissions via the browser's native permission dialog.
  ///
  /// **Platform Limitation:**
  /// This method always throws [UnimplementedError] on non-web platforms.
  /// Use platform-specific permission APIs for mobile/desktop.
  ///
  /// **Returns:**
  /// A [Future<bool>] that resolves to:
  /// - `true` if the user granted notification permissions (web only)
  /// - `false` if the user denied permissions (web only)
  /// - Never completes on non-web platforms (throws instead)
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: shows browser permission dialog
  /// // On mobile/desktop: throws UnimplementedError
  /// final granted = await notificationService.requestPermissions();
  /// ```
  Future<bool> requestPermissions() async {
    throw UnimplementedError(
      'NotificationServiceWeb.requestPermissions is only available on web platform',
    );
  }

  /// Deletes the FCM token and unregisters it from the backend.
  ///
  /// On web platforms, this method:
  /// - Unregisters the FCM token from the Supabase backend
  /// - Deletes the token from Firebase Cloud Messaging
  /// - Opts the user out of receiving push notifications
  ///
  /// **Platform Limitation:**
  /// This method always throws [UnimplementedError] on non-web platforms.
  /// Use platform-specific token deletion APIs for mobile/desktop.
  ///
  /// **Returns:**
  /// A [Future] that completes when the token is deleted (web only).
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: deletes FCM token and unregisters from backend
  /// // On mobile/desktop: throws UnimplementedError
  /// await notificationService.deleteToken();
  /// ```
  Future<void> deleteToken() async {
    throw UnimplementedError(
      'NotificationServiceWeb.deleteToken is only available on web platform',
    );
  }

  /// Gets the current Firebase Cloud Messaging token.
  ///
  /// On web platforms, this getter returns the FCM token obtained during
  /// initialization, or `null` if no token has been obtained yet.
  ///
  /// **Platform Limitation:**
  /// This getter always throws [UnimplementedError] on non-web platforms.
  /// Use platform-specific token retrieval for mobile/desktop.
  ///
  /// **Returns:**
  /// - Web: `String?` containing the FCM token, or `null` if not available
  /// - Non-web: Never returns (throws instead)
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: returns FCM token string or null
  /// // On mobile/desktop: throws UnimplementedError
  /// final token = notificationService.fcmToken;
  /// ```
  String? get fcmToken {
    throw UnimplementedError(
      'NotificationServiceWeb.fcmToken is only available on web platform',
    );
  }

  /// Checks if the notification service has been initialized.
  ///
  /// On web platforms, this getter returns `true` if [initialize] has
  /// completed successfully, or `false` otherwise.
  ///
  /// **Platform Limitation:**
  /// This getter always throws [UnimplementedError] on non-web platforms.
  /// Use platform checks before accessing notification services.
  ///
  /// **Returns:**
  /// - Web: `bool` indicating initialization status
  /// - Non-web: Never returns (throws instead)
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: returns true/false based on initialization state
  /// // On mobile/desktop: throws UnimplementedError
  /// if (notificationService.isInitialized) {
  ///   // Service is ready
  /// }
  /// ```
  bool get isInitialized {
    throw UnimplementedError(
      'NotificationServiceWeb.isInitialized is only available on web platform',
    );
  }

  /// Disposes of resources and cleans up the notification service.
  ///
  /// On web platforms, this method:
  /// - Cancels auth state subscriptions
  /// - Closes stream controllers
  /// - Releases token manager and message handler resources
  ///
  /// **Platform Limitation:**
  /// This method always throws [UnimplementedError] on non-web platforms.
  /// Use platform-specific cleanup for mobile/desktop.
  ///
  /// **Throws:**
  /// - [UnimplementedError]: Always thrown on non-web platforms
  ///
  /// **Example:**
  /// ```dart
  /// // On web: cleans up FCM resources
  /// // On mobile/desktop: throws UnimplementedError
  /// notificationService.dispose();
  /// ```
  void dispose() {
    throw UnimplementedError(
      'NotificationServiceWeb.dispose is only available on web platform',
    );
  }
}
