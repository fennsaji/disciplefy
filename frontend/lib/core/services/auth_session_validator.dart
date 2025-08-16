import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';

/// AuthSessionValidator monitors app lifecycle to validate authentication
/// sessions when the app resumes from background.
///
/// This prevents issues where tokens expire while the app is backgrounded,
/// ensuring session consistency when users return to the app.
///
/// Part of Phase 3: Monitoring & Prevention
class AuthSessionValidator extends WidgetsBindingObserver {
  final AuthBloc _authBloc;

  AuthSessionValidator(this._authBloc);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (kDebugMode) {
      print('🔄 [APP LIFECYCLE] State changed to: $state');
    }

    // Validate session when app returns from background
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('🔄 [APP LIFECYCLE] App resumed - triggering session validation');
      }

      // Trigger session validation to ensure auth state is still valid
      _authBloc.add(const SessionValidationRequested());
    } else if (state == AppLifecycleState.paused) {
      if (kDebugMode) {
        print(
            '🔄 [APP LIFECYCLE] App paused - session will be validated on resume');
      }
    }
  }

  /// Register this observer with WidgetsBinding
  void register() {
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      print('✅ [AUTH SESSION VALIDATOR] Registered app lifecycle observer');
    }
  }

  /// Unregister this observer from WidgetsBinding
  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
    if (kDebugMode) {
      print('🧹 [AUTH SESSION VALIDATOR] Unregistered app lifecycle observer');
    }
  }
}
