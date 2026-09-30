import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/logger.dart';

/// Shared, per-user cache for the `GET /user-profile` response.
///
/// - In memory for the session; considered fresh for [freshFor].
/// - Persisted in SharedPreferences keyed by user id, so a relaunch shows the
///   last known profile immediately while a background request revalidates it
///   (stale-while-revalidate).
/// - Concurrent readers share one in-flight request.
/// - Only successful responses containing a profile are cached; errors
///   (401/404/5xx) always go to the network so their semantics are unchanged.
/// - Invalidated on profile updates, logout and user switch.
class UserProfileCache {
  UserProfileCache({
    String? Function()? currentUserId,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    this.freshFor = const Duration(minutes: 5),
  })  : _currentUserId = currentUserId ?? _supabaseUserId,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  /// Process-wide instance shared by every [UserProfileApiService].
  static UserProfileCache instance = UserProfileCache();

  static const String _keyPrefix = 'user_profile_cache_v1_';

  final String? Function() _currentUserId;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final Duration freshFor;

  String? _userId;
  String? _body;

  /// When [_body] was last fetched from the network (null = from disk only).
  DateTime? _fetchedAt;

  Future<http.Response>? _inFlight;
  String? _inFlightUserId;

  /// Bumped on every invalidation so responses to requests started before an
  /// update / logout are never written back into the cache.
  int _generation = 0;

  static String? _supabaseUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Returns the profile response, from cache when possible.
  Future<http.Response> get(Future<http.Response> Function() fetch) async {
    final userId = _currentUserId();
    if (userId == null) return fetch();

    if (_userId != userId) {
      _resetMemory();
      _userId = userId;
    }

    if (_body != null) {
      final fetchedAt = _fetchedAt;
      if (fetchedAt == null || _now().difference(fetchedAt) >= freshFor) {
        _revalidate(userId, fetch);
      }
      return _response(_body!);
    }

    final persisted = await _readPersisted(userId);
    if (persisted != null && _currentUserId() == userId && _body == null) {
      _userId = userId;
      _body = persisted;
      _fetchedAt = null;
      _revalidate(userId, fetch);
      return _response(persisted);
    }
    if (_body != null && _userId == userId) return _response(_body!);

    return _fetch(userId, fetch);
  }

  /// Drops the in-memory and persisted profile for the current user
  /// (call after any profile write).
  Future<void> invalidate() async {
    final userId = _userId ?? _currentUserId();
    _resetMemory();
    if (userId == null) return;
    try {
      final prefs = await _prefs();
      await prefs.remove('$_keyPrefix$userId');
    } catch (e) {
      Logger.debug('User profile cache: failed to clear persisted entry: $e');
    }
  }

  /// Drops every cached profile (logout).
  Future<void> clearAll() async {
    _resetMemory();
    _userId = null;
    try {
      final prefs = await _prefs();
      final keys =
          prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      Logger.debug('User profile cache: failed to clear persisted entries: $e');
    }
  }

  void _resetMemory() {
    _generation++;
    _body = null;
    _fetchedAt = null;
    _inFlight = null;
    _inFlightUserId = null;
  }

  void _revalidate(String userId, Future<http.Response> Function() fetch) {
    unawaited(_fetch(userId, fetch).then<void>((_) {}, onError: (Object e) {
      Logger.debug('User profile background refresh failed: $e');
    }));
  }

  Future<http.Response> _fetch(
      String userId, Future<http.Response> Function() fetch) {
    final existing = _inFlight;
    if (existing != null && _inFlightUserId == userId) return existing;

    final generation = _generation;
    late final Future<http.Response> request;
    request = fetch().then((response) {
      if (generation == _generation &&
          _currentUserId() == userId &&
          _isProfileResponse(response)) {
        _userId = userId;
        _body = response.body;
        _fetchedAt = _now();
        unawaited(_writePersisted(userId, response.body));
      }
      return response;
    }).whenComplete(() {
      if (identical(_inFlight, request)) {
        _inFlight = null;
        _inFlightUserId = null;
      }
    });
    _inFlight = request;
    _inFlightUserId = userId;
    return request;
  }

  static bool _isProfileResponse(http.Response response) {
    if (response.statusCode != 200) return false;
    try {
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final profile = decoded['data'] ?? decoded;
      return profile is Map && profile['id'] != null;
    } catch (_) {
      return false;
    }
  }

  static http.Response _response(String body) => http.Response(body, 200,
      headers: const {'content-type': 'application/json; charset=utf-8'});

  Future<String?> _readPersisted(String userId) async {
    try {
      final prefs = await _prefs();
      return prefs.getString('$_keyPrefix$userId');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersisted(String userId, String body) async {
    try {
      final prefs = await _prefs();
      await prefs.setString('$_keyPrefix$userId', body);
    } catch (e) {
      Logger.debug('User profile cache: failed to persist: $e');
    }
  }
}
