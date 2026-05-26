import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

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
    Logger.debug(
        '🚀 [AUTH NOTIFIER] Initialization started at ${initStartTime.toIso8601String()}');

    // Check initial auth state (may be null during restoration)
    _isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    // ANDROID DEBUG: Log initial state
    Logger.debug(
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
        Logger.debug(
            '📨 [AUTH NOTIFIER] Auth state event received after ${timeSinceInit}ms:');
        Logger.debug('   └─ Event: ${authState.event}');
        Logger.debug(
            '   └─ Session: ${authState.session != null ? "exists" : "null"}');
        Logger.debug('   └─ User: ${authState.session?.user.id ?? "null"}');
        Logger.debug(
            '   └─ Was authenticated: $wasAuthenticated → Now: $_isAuthenticated');

        // ANDROID FIX: Mark as initialized after first auth state event
        // This indicates Supabase has completed session restoration
        if (!_isInitialized) {
          _isInitialized = true;
          // Cancel timeout timer since initialization completed normally
          _initTimeout?.cancel();
          _initTimeout = null;
          Logger.debug(
              '✅ [AUTH NOTIFIER] Session restoration complete - auth initialized after ${timeSinceInit}ms');
        }

        // Keep local session_expires_at in sync with Supabase token refreshes.
        // Without this, the RouterGuard's _isSessionExpired() reads a stale
        // expiry from Hive and incorrectly treats the user as logged out,
        // causing a redirect bounce (home → login → home → error page).
        if (authState.session != null &&
            (authState.event == AuthChangeEvent.tokenRefreshed ||
                authState.event == AuthChangeEvent.signedIn)) {
          _syncSessionExpiry(authState.session!);
        }

        // Notify if auth state changed, if this is the first initialization,
        // or if this is a signedOut event — even when the Supabase session was
        // already null (e.g. expired) we must notify so the router re-evaluates
        // and clears stale Hive credentials.
        if (wasAuthenticated != _isAuthenticated ||
            !wasInitialized ||
            authState.event == AuthChangeEvent.signedOut) {
          Logger.debug('🔄 [AUTH NOTIFIER] Notifying router of state change');
          notifyListeners();
        } else {
          Logger.debug(
              '⏭️  [AUTH NOTIFIER] State unchanged, skipping notification');
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
        Logger.warning(
            '⏱️ [AUTH NOTIFIER] TIMEOUT after ${timeSinceInit}ms - no auth event received');
        Logger.warning(
            '⚠️  [AUTH NOTIFIER] Forcing initialization to prevent infinite loading');
        Logger.debug(
            '   └─ Current user: ${Supabase.instance.client.auth.currentUser?.id ?? "null"}');
        Logger.debug('   └─ Is authenticated: $_isAuthenticated');
        notifyListeners();
      } else if (_isDisposed) {
        Logger.debug(
            '🗑️  [AUTH NOTIFIER] Timeout fired but already disposed, ignoring');
      } else {
        Logger.info(
            '✅ [AUTH NOTIFIER] Timeout fired but already initialized, ignoring');
      }
    });

    Logger.debug('⏳ [AUTH NOTIFIER] 5-second timeout timer started');
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized =>
      _isInitialized; // ANDROID FIX: Expose initialization state

  /// Sync Hive session_expires_at with the latest Supabase token expiry.
  /// Prevents RouterGuard from treating auto-refreshed sessions as expired.
  void _syncSessionExpiry(Session session) {
    try {
      final expiresAt = session.expiresAt;
      if (expiresAt == null) return;

      final expiresAtDt =
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);

      if (!Hive.isBoxOpen('app_settings')) return;
      final box = Hive.box('app_settings');
      box.put('session_expires_at', expiresAtDt.toIso8601String());

      Logger.debug(
          '🔄 [AUTH NOTIFIER] Synced session_expires_at to ${expiresAtDt.toIso8601String()}');
    } catch (e) {
      Logger.error('Failed to sync session expiry to Hive',
          tag: 'AUTH_NOTIFIER', error: e);
    }
  }

  @override
  void dispose() {
    Logger.debug('🗑️  [AUTH NOTIFIER] Disposing - cleaning up resources');

    // Mark as disposed to prevent timer callback from running
    _isDisposed = true;

    // Cancel and clear the initialization timeout timer
    if (_initTimeout != null) {
      _initTimeout?.cancel();
      _initTimeout = null;
      Logger.debug('   └─ Timeout timer cancelled');
    }

    // Cancel auth state subscription
    _authSubscription.cancel();
    Logger.debug('   └─ Auth subscription cancelled');

    Logger.debug('✅ [AUTH NOTIFIER] Disposal complete');

    super.dispose();
  }
}
