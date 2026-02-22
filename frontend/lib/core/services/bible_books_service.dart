import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/bible_books.dart';
import '../models/bible_books_config.dart';
import '../utils/logger.dart';

/// Service that fetches Bible book name configuration from the `get-bible-books`
/// Edge Function and caches it locally with a 30-day TTL.
///
/// On startup:
///   1. Loads from SharedPreferences immediately (no latency).
///   2. If cache is stale/missing, fetches fresh data from the API in the background.
///
/// The [BibleBooks] class falls back to its static constants if no remote data
/// is loaded yet, so the app works even on first launch without network.
class BibleBooksService {
  static const String _cacheKey = 'bible_books_config_v1';
  static const String _cacheTimestampKey = 'bible_books_config_v1_timestamp';
  static const Duration _cacheDuration = Duration(days: 30);

  DateTime? _lastFetch;

  /// Initialize the service: serve cached data immediately, then refresh if stale.
  Future<void> initialize() async {
    try {
      await _loadFromCache();
      if (!_isCacheValid()) {
        await _fetchFromApi();
      }
    } catch (e) {
      Logger.debug('⚠️ [BibleBooksService] Error initializing: $e');
      // Falls back to BibleBooks static constants — no crash.
    }
  }

  /// Fetch fresh config from the Edge Function and update [BibleBooks] + cache.
  Future<void> _fetchFromApi() async {
    try {
      Logger.debug(
          '🔄 [BibleBooksService] Fetching Bible book config from API...');

      final response = await Supabase.instance.client.functions.invoke(
        'get-bible-books',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception('API error: ${responseData['error']}');
      }

      final payload = responseData['data'] as Map<String, dynamic>;
      final booksData = payload['data'] as Map<String, dynamic>;
      final version = (payload['version'] as num?)?.toInt() ?? 1;

      final config = BibleBooksConfig.fromJson({
        ...booksData,
        'version': version,
      });

      BibleBooks.loadRemoteData(config);
      _lastFetch = DateTime.now();
      await _saveToCache(config);

      Logger.debug(
          '✅ [BibleBooksService] Bible book config loaded (v$version)');
    } catch (e) {
      Logger.debug('❌ [BibleBooksService] Error fetching from API: $e');
      // Keeps using cached/static data.
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTimestampKey);

      if (json != null && ts != null) {
        final config = BibleBooksConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        BibleBooks.loadRemoteData(config);
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        Logger.debug(
          '✅ [BibleBooksService] Loaded Bible book config from cache (v${config.version})',
        );
      }
    } catch (e) {
      Logger.debug('⚠️ [BibleBooksService] Error loading from cache: $e');
    }
  }

  Future<void> _saveToCache(BibleBooksConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = (_lastFetch ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
      await prefs.setInt(_cacheTimestampKey, ts);
      Logger.debug('✅ [BibleBooksService] Saved Bible book config to cache');
    } catch (e) {
      Logger.debug('⚠️ [BibleBooksService] Error saving to cache: $e');
    }
  }

  bool _isCacheValid() =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;
}
