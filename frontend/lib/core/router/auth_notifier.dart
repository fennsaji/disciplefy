import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Auth state notifier for GoRouter refresh
/// Listens to Supabase auth changes and notifies router to refresh
class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isAuthenticated = false;
  bool _isInitialized =
      false; // ANDROID FIX: Track if session restoration is complete

  AuthNotifier() {
    _initialize();
  }

  void _initialize() {
    // ANDROID FIX: Start as not initialized - session restoration in progress
    _isInitialized = false;

    // Check initial auth state (may be null during restoration)
    _isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    // Listen to auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        final wasAuthenticated = _isAuthenticated;
        final wasInitialized = _isInitialized;

        _isAuthenticated = authState.session?.user != null;

        // ANDROID FIX: Mark as initialized after first auth state event
        // This indicates Supabase has completed session restoration
        if (!_isInitialized) {
          _isInitialized = true;
          print(
              '🔄 [AUTH NOTIFIER] Session restoration complete - auth initialized');
        }

        // Notify if auth state changed OR if this is the first initialization
        if (wasAuthenticated != _isAuthenticated || !wasInitialized) {
          print(
              '🔄 [AUTH NOTIFIER] Auth state changed: wasAuthenticated=$wasAuthenticated, isAuthenticated=$_isAuthenticated, isInitialized=$_isInitialized');
          notifyListeners();
        }
      },
    );

    // ANDROID FIX: Fallback timeout to prevent infinite loading
    // If no auth state event within 2 seconds, mark as initialized anyway
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isInitialized) {
        _isInitialized = true;
        print(
            '🔄 [AUTH NOTIFIER] Timeout reached - marking auth as initialized');
        notifyListeners();
      }
    });
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized =>
      _isInitialized; // ANDROID FIX: Expose initialization state

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
