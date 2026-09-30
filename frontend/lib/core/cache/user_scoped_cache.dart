import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Captures who was signed in (and which cache generation was current) when a
/// request started, so its response is only stored if nothing changed since.
class UserCacheTicket {
  const UserCacheTicket._(this.userId, this.generation);

  final String? userId;
  final int generation;
}

/// Persisted, per-user JSON cache used for stale-while-revalidate screens
/// (token balance, subscription, usage stats, fellowships).
///
/// - Entries are keyed by the signed-in user's id (plus an optional variant,
///   e.g. a language code), so one user's data is never read for another.
/// - Callers take a [ticket] before a network request and pass it to [write];
///   a write is dropped when the user changed or the cache was invalidated in
///   the meantime (logout, purchase, join/leave...).
/// - Values are only ever shown as a placeholder: callers always refresh.
/// - [clearAll] is called at logout, alongside the user profile cache.
class UserScopedCache {
  UserScopedCache({
    String? Function()? currentUserId,
    Future<SharedPreferences> Function()? prefs,
  })  : _currentUserId = currentUserId ?? _supabaseUserId,
        _prefs = prefs ?? SharedPreferences.getInstance;

  /// Process-wide instance.
  static UserScopedCache instance = UserScopedCache();

  static const String _keyPrefix = 'user_scoped_cache_v1|';

  /// Cache names.
  static const String tokenStatus = 'token_status';
  static const String activeSubscription = 'active_subscription';
  static const String subscriptionStatus = 'subscription_status';
  static const String usageStats = 'usage_stats';
  static const String fellowships = 'fellowships';
  static const String discoverFellowships = 'discover_fellowships';

  final String? Function() _currentUserId;
  final Future<SharedPreferences> Function() _prefs;

  /// In-memory mirror of persisted entries (full key -> JSON string).
  final Map<String, String> _memory = {};

  /// Bumped per cache name on invalidation; [_globalGeneration] on clearAll.
  final Map<String, int> _nameGenerations = {};
  int _globalGeneration = 0;

  static String? _supabaseUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// The signed-in user's id, or null when signed out.
  String? get currentUserId => _currentUserId();

  int _generationFor(String name) =>
      _globalGeneration * 1000003 + (_nameGenerations[name] ?? 0);

  static String _key(String name, String userId, String? variant) =>
      '$_keyPrefix$name|$userId|${variant ?? ''}';

  /// Takes a ticket for a request that will populate [name].
  UserCacheTicket ticket(String name) =>
      UserCacheTicket._(_currentUserId(), _generationFor(name));

  /// Reads the decoded JSON stored for the current user, or null.
  Future<Object?> read(String name, {String? variant}) async {
    final userId = _currentUserId();
    if (userId == null) return null;
    final key = _key(name, userId, variant);
    var raw = _memory[key];
    if (raw == null) {
      try {
        raw = (await _prefs()).getString(key);
      } catch (_) {
        raw = null;
      }
      // The user may have signed out while reading from disk.
      if (raw == null || _currentUserId() != userId) return null;
      _memory[key] = raw;
    }
    try {
      return json.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Stores [value] (JSON-encodable) if [ticket] is still current.
  Future<void> write(UserCacheTicket ticket, String name, Object? value,
      {String? variant}) async {
    final userId = ticket.userId;
    if (userId == null ||
        _currentUserId() != userId ||
        ticket.generation != _generationFor(name)) {
      return;
    }
    final key = _key(name, userId, variant);
    final String raw;
    try {
      raw = json.encode(value);
    } catch (e) {
      Logger.debug('User cache: could not encode $name: $e');
      return;
    }
    _memory[key] = raw;
    try {
      await (await _prefs()).setString(key, raw);
    } catch (e) {
      Logger.debug('User cache: failed to persist $name: $e');
    }
  }

  /// Drops every variant of [name] for the current user and discards any
  /// response already in flight for it.
  Future<void> invalidate(String name) async {
    _nameGenerations[name] = (_nameGenerations[name] ?? 0) + 1;
    final userId = _currentUserId();
    if (userId == null) return;
    final prefix = '$_keyPrefix$name|$userId|';
    _memory.removeWhere((k, _) => k.startsWith(prefix));
    await _removeWhere((k) => k.startsWith(prefix));
  }

  /// Drops every entry of every user (logout).
  Future<void> clearAll() async {
    _globalGeneration++;
    _memory.clear();
    await _removeWhere((k) => k.startsWith(_keyPrefix));
  }

  Future<void> _removeWhere(bool Function(String key) test) async {
    try {
      final prefs = await _prefs();
      final keys = prefs.getKeys().where(test).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      Logger.debug('User cache: failed to clear entries: $e');
    }
  }
}
