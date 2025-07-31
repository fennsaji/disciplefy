import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Auth state notifier for GoRouter refresh
/// Listens to Supabase auth changes and notifies router to refresh
class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isAuthenticated = false;

  AuthNotifier() {
    _initialize();
  }

  void _initialize() {
    // Check initial auth state
    _isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    
    // Listen to auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState authState) {
        final wasAuthenticated = _isAuthenticated;
        _isAuthenticated = authState.session?.user != null;
        
        // Only notify if auth state actually changed
        if (wasAuthenticated != _isAuthenticated) {
          print('🔄 [AUTH NOTIFIER] Auth state changed: wasAuthenticated=$wasAuthenticated, isAuthenticated=$_isAuthenticated');
          notifyListeners();
        }
      },
    );
  }

  bool get isAuthenticated => _isAuthenticated;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}