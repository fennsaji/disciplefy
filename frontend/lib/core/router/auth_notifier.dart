import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Auth state notifier for GoRouter refresh
/// Listens to Supabase auth changes and notifies router to refresh
class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _authSubscription;
  Timer? _initTimeout; // ANDROID FIX: Timeout timer for fallback initialization
  bool _isAuthenticated = false;
  bool _isInitialized =
      false; // ANDROID FIX: Track if session restoration is complete
  bool _isDisposed =
      false; // Track disposal state to prevent post-dispose operations

  AuthNotifier() {
    _initialize();
  }

  void _initialize() {
    // ANDROID FIX: Start as not initialized - session restoration in progress
    _isInitialized = false;

    // ANDROID DEBUG: Log initialization start with timestamp
    final initStartTime = DateTime.now();
    print(
        '🚀 [AUTH NOTIFIER] Initialization started at ${initStartTime.toIso8601String()}');

    // Check initial auth state (may be null during restoration)
    _isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    // ANDROID DEBUG: Log initial state
    print(
        '📊 [AUTH NOTIFIER] Initial state: isAuthenticated=$_isAuthenticated, user=${Supabase.instance.client.auth.currentUser?.id ?? "null"}');

    // Listen to auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        final eventTime = DateTime.now();
        final timeSinceInit =
            eventTime.difference(initStartTime).inMilliseconds;

        final wasAuthenticated = _isAuthenticated;
        final wasInitialized = _isInitialized;

        _isAuthenticated = authState.session?.user != null;

        // ANDROID DEBUG: Log auth state event details
        print(
            '📨 [AUTH NOTIFIER] Auth state event received after ${timeSinceInit}ms:');
        print('   └─ Event: ${authState.event}');
        print(
            '   └─ Session: ${authState.session != null ? "exists" : "null"}');
        print('   └─ User: ${authState.session?.user.id ?? "null"}');
        print(
            '   └─ Was authenticated: $wasAuthenticated → Now: $_isAuthenticated');

        // ANDROID FIX: Mark as initialized after first auth state event
        // This indicates Supabase has completed session restoration
        if (!_isInitialized) {
          _isInitialized = true;
          // Cancel timeout timer since initialization completed normally
          _initTimeout?.cancel();
          _initTimeout = null;
          print(
              '✅ [AUTH NOTIFIER] Session restoration complete - auth initialized after ${timeSinceInit}ms');
        }

        // Notify if auth state changed OR if this is the first initialization
        if (wasAuthenticated != _isAuthenticated || !wasInitialized) {
          print('🔄 [AUTH NOTIFIER] Notifying router of state change');
          notifyListeners();
        } else {
          print('⏭️  [AUTH NOTIFIER] State unchanged, skipping notification');
        }
      },
    );

    // ANDROID FIX: Fallback timeout to prevent infinite loading
    // If no auth state event within 5 seconds, mark as initialized anyway
    // Increased from 2s to 5s to accommodate slow Android devices and network delays
    _initTimeout = Timer(const Duration(seconds: 5), () {
      final timeoutTime = DateTime.now();
      final timeSinceInit =
          timeoutTime.difference(initStartTime).inMilliseconds;

      // Only proceed if not disposed and not already initialized
      if (!_isDisposed && !_isInitialized) {
        _isInitialized = true;
        print(
            '⏱️ [AUTH NOTIFIER] TIMEOUT after ${timeSinceInit}ms - no auth event received');
        print(
            '⚠️  [AUTH NOTIFIER] Forcing initialization to prevent infinite loading');
        print(
            '   └─ Current user: ${Supabase.instance.client.auth.currentUser?.id ?? "null"}');
        print('   └─ Is authenticated: $_isAuthenticated');
        notifyListeners();
      } else if (_isDisposed) {
        print(
            '🗑️  [AUTH NOTIFIER] Timeout fired but already disposed, ignoring');
      } else {
        print(
            '✅ [AUTH NOTIFIER] Timeout fired but already initialized, ignoring');
      }
    });

    print('⏳ [AUTH NOTIFIER] 5-second timeout timer started');
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized =>
      _isInitialized; // ANDROID FIX: Expose initialization state

  @override
  void dispose() {
    print('🗑️  [AUTH NOTIFIER] Disposing - cleaning up resources');

    // Mark as disposed to prevent timer callback from running
    _isDisposed = true;

    // Cancel and clear the initialization timeout timer
    if (_initTimeout != null) {
      _initTimeout?.cancel();
      _initTimeout = null;
      print('   └─ Timeout timer cancelled');
    }

    // Cancel auth state subscription
    _authSubscription.cancel();
    print('   └─ Auth subscription cancelled');

    print('✅ [AUTH NOTIFIER] Disposal complete');

    super.dispose();
  }
}
