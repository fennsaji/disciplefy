// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-specific implementation for browser history management
void clearBrowserHistory(String newRoute) {
  // Replace browser history state to prevent back navigation to pre-auth screens
  html.window.history.replaceState(null, '', newRoute);
}
