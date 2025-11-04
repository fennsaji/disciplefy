// Stub file for non-web platforms
// This file is used when building for mobile/desktop platforms
// The actual web implementation is in notification_service_web.dart

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub class for NotificationServiceWeb on non-web platforms
/// This class should never be instantiated on mobile/desktop
///
/// NOTE: This stub must maintain API parity with notification_service_web.dart
/// to ensure type safety across conditional imports.
class NotificationServiceWeb {
  NotificationServiceWeb({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  }) {
    throw UnimplementedError(
      'NotificationServiceWeb is only available on web platform',
    );
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    throw UnimplementedError(
      'NotificationServiceWeb.initialize is only available on web platform',
    );
  }

  /// Request notification permissions from the browser
  Future<bool> requestPermissions() async {
    throw UnimplementedError(
      'NotificationServiceWeb.requestPermissions is only available on web platform',
    );
  }

  /// Delete the FCM token and unregister from backend
  Future<void> deleteToken() async {
    throw UnimplementedError(
      'NotificationServiceWeb.deleteToken is only available on web platform',
    );
  }

  /// Get the current FCM token (null if not obtained)
  String? get fcmToken {
    throw UnimplementedError(
      'NotificationServiceWeb.fcmToken is only available on web platform',
    );
  }

  /// Check if the service has been initialized
  bool get isInitialized {
    throw UnimplementedError(
      'NotificationServiceWeb.isInitialized is only available on web platform',
    );
  }

  /// Dispose resources and clean up
  void dispose() {
    throw UnimplementedError(
      'NotificationServiceWeb.dispose is only available on web platform',
    );
  }
}
