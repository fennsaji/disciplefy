import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

/// True when the current viewer is a global app admin.
///
/// Falls back to `false` when no [AuthBloc] is available in [context] (e.g.
/// a widget test tree without the auth provider), rather than throwing.
bool isViewerAdmin(BuildContext context) {
  try {
    final authState = context.read<AuthBloc>().state;
    return authState is auth_states.AuthenticatedState && authState.isAdmin;
  } catch (_) {
    return false;
  }
}
