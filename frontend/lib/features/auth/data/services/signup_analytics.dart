import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

/// Sign-up methods reported in `nux.signup_completed`.
const Set<String> _methods = {'google', 'apple', 'email'};

/// Sends `nux.signup_completed` with [method] (google, apple or email) and
/// whether the account came from a guest. Never throws.
void trackSignupCompleted(String method, {required bool fromGuest}) {
  ActivationAnalytics.maybeTrack(NuxEvent.signupCompleted, {
    'method': _methods.contains(method) ? method : 'other',
    'from_guest': fromGuest,
  });
}

/// True when [user]'s account was created by the sign-in that just ran: it
/// was created and last signed in within a minute of each other. Both times
/// come from the server, so the device clock does not matter.
bool isNewAccount(User user) {
  final created = DateTime.tryParse(user.createdAt);
  final lastSignIn =
      user.lastSignInAt == null ? null : DateTime.tryParse(user.lastSignInAt!);
  if (created == null || lastSignIn == null) return false;
  return lastSignIn.difference(created).abs() < const Duration(minutes: 1);
}

/// Reports a Google/Apple sign-in as a sign-up when it created the account.
void trackSignupIfNew(User user, String method) {
  if (isNewAccount(user)) trackSignupCompleted(method, fromGuest: false);
}
