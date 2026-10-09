import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The one learning path the signed-in guest is enrolled in, as last seen
/// in data the app already loads: Home's active path (the recommended-path
/// call, cross-checked with the enrolled list) and the Topics listing.
///
/// A guest gets one path only. Once this is known every other path is
/// locked for them (reason `second_path`). The value belongs to the user it
/// was recorded for, so a new guest after sign-out never inherits it.
class GuestPathEnrollment {
  GuestPathEnrollment._();

  /// Fires whenever the recorded path changes, so locks can repaint.
  static final ValueNotifier<String?> changes = ValueNotifier<String?>(null);

  static String? _ownerId;

  /// Current user id. Overridable in tests.
  @visibleForTesting
  static String? Function() currentUserId = _supabaseUserId;

  static String? _supabaseUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// The enrolled path id for the current user, or null when none is known.
  static String? get pathId {
    final value = changes.value;
    if (value == null) return null;
    return _ownerId == currentUserId() ? value : null;
  }

  /// Records [pathId] (null: the user has no enrolled path) for the current
  /// user.
  static void record(String? pathId) {
    _ownerId = currentUserId();
    changes.value = pathId;
  }

  /// Forgets the recorded path (tests).
  @visibleForTesting
  static void reset() {
    _ownerId = null;
    changes.value = null;
    currentUserId = _supabaseUserId;
  }
}
