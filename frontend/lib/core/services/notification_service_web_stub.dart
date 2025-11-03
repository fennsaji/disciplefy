// Stub file for non-web platforms
// This file is used when building for mobile/desktop platforms
// The actual web implementation is in notification_service_web.dart

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub class for NotificationServiceWeb on non-web platforms
/// This class should never be instantiated on mobile/desktop
class NotificationServiceWeb {
  NotificationServiceWeb({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  }) {
    throw UnimplementedError(
      'NotificationServiceWeb is only available on web platform',
    );
  }

  Future<void> initialize() async {
    throw UnimplementedError(
      'NotificationServiceWeb is only available on web platform',
    );
  }

  void dispose() {
    throw UnimplementedError(
      'NotificationServiceWeb is only available on web platform',
    );
  }
}
