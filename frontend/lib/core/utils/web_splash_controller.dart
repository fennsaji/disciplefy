import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Controller for web splash screen management
class WebSplashController {
  /// Signals to the web page that Flutter is ready and initialized
  static void signalFlutterReady() {
    if (kIsWeb) {
      try {
        // The splash screen JavaScript will automatically hide after 5 seconds
        // This is just to ensure the app is ready if needed
        Logger.debug('Flutter app is ready');
      } catch (e) {
        Logger.debug('Could not signal Flutter ready: $e');
      }
    }
  }
}
