import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Names whose data a learning cache entry belongs to.
///
/// Learning path lists, the recommended path and "For You" topics carry the
/// signed-in user's enrollment and progress, and the persistent copies (Hive)
/// outlive a logout. Every cache key is prefixed with [currentUserKey], so a
/// different account — or a signed-out session — can never be served the
/// previous user's data.
class LearningCacheScope {
  LearningCacheScope._();

  /// Key used when nobody is signed in (or auth is not initialised yet).
  static const String signedOutKey = 'signed_out';

  static String Function() _resolver = _supabaseUserId;

  /// Overrides how the current user id is read. Pass null to restore the
  /// default (Supabase auth).
  @visibleForTesting
  static set resolver(String Function()? resolver) =>
      _resolver = resolver ?? _supabaseUserId;

  /// Id of the current user, or [signedOutKey]. Never throws.
  static String currentUserKey() {
    try {
      final key = _resolver();
      return key.isEmpty ? signedOutKey : key;
    } catch (_) {
      return signedOutKey;
    }
  }

  /// Cache scope for language-dependent, user-specific content.
  static String scopeFor(String language) => '${currentUserKey()}|$language';

  static String _supabaseUserId() =>
      Supabase.instance.client.auth.currentUser?.id ?? signedOutKey;
}
