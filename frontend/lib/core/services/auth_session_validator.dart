import 'package:flutter/widgets.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../utils/logger.dart';

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

    Logger.debug('🔄 [APP LIFECYCLE] State changed to: $state');

    // Validate session when app returns from background
    if (state == AppLifecycleState.resumed) {
      Logger.debug(
          '🔄 [APP LIFECYCLE] App resumed - triggering session validation');

      // Delay validation slightly on Android: network interfaces need ~1-2s to
      // re-establish after resume. Without the delay, token refresh fails on the
      // first attempt (no network) and the user gets logged out unnecessarily.
      Future.delayed(const Duration(milliseconds: 1500), () {
        _authBloc.add(const SessionValidationRequested());
      });
    } else if (state == AppLifecycleState.paused) {
      Logger.debug(
          '🔄 [APP LIFECYCLE] App paused - session will be validated on resume');
    }
  }

  /// Register this observer with WidgetsBinding
  void register() {
    WidgetsBinding.instance.addObserver(this);
    Logger.debug(
        '✅ [AUTH SESSION VALIDATOR] Registered app lifecycle observer');
  }

  /// Unregister this observer from WidgetsBinding
  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
    Logger.debug(
        '🧹 [AUTH SESSION VALIDATOR] Unregistered app lifecycle observer');
  }
}
