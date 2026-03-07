import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/logger.dart';

/// Caches fetched verse text locally for 1 day to avoid redundant API calls.
///
/// Cache key: '{reference}_{language}' (e.g., 'John_3_16_en')
class VerseCacheService {
  static const String _boxName = 'verse_text_cache';
  static const int _cacheDurationHours = 24;

  late Box<Map> _cacheBox;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _cacheBox = Hive.isBoxOpen(_boxName)
          ? Hive.box<Map>(_boxName)
          : await Hive.openBox<Map>(_boxName);
      _isInitialized = true;
      await _cleanupOldEntries();
    } catch (e) {
      Logger.debug('⚠️ [VERSE_CACHE] Failed to initialize: $e');
    }
  }

  /// Store a fetched verse in the cache.
  Future<void> cacheVerse({
    required String reference,
    required String language,
    required String text,
    required String localizedReference,
    List<Map<String, dynamic>>? verses,
  }) async {
    await _ensureInitialized();
    try {
      final key = _cacheKey(reference, language);
      await _cacheBox.put(key, {
        'text': text,
        'localized_reference': localizedReference,
        if (verses != null) 'verses': verses,
        'cached_at': DateTime.now().toIso8601String(),
      });
      Logger.debug('✅ [VERSE_CACHE] Cached verse: $key');
    } catch (e) {
      Logger.debug('❌ [VERSE_CACHE] Failed to cache verse: $e');
    }
  }

  /// Returns cached verse data, or null if not cached / expired.
  Future<CachedVerseData?> getCachedVerse({
    required String reference,
    required String language,
  }) async {
    await _ensureInitialized();
    try {
      final key = _cacheKey(reference, language);
      final data = _cacheBox.get(key);
      if (data == null) return null;

      final cachedAt = DateTime.parse(data['cached_at'] as String);
      if (DateTime.now().difference(cachedAt).inHours >= _cacheDurationHours) {
        await _cacheBox.delete(key);
        Logger.debug('⏰ [VERSE_CACHE] Cache expired: $key');
        return null;
      }

      Logger.debug('✅ [VERSE_CACHE] Cache hit: $key');
      final rawVerses = data['verses'] as List<dynamic>?;
      return CachedVerseData(
        text: data['text'] as String,
        localizedReference: data['localized_reference'] as String,
        verses: rawVerses
            ?.map((v) =>
                {'number': v['number'] as int, 'text': v['text'] as String})
            .toList(),
      );
    } catch (e) {
      Logger.debug('❌ [VERSE_CACHE] Error reading cache: $e');
      return null;
    }
  }

  String _cacheKey(String reference, String language) =>
      '${reference.replaceAll(RegExp(r'\s+'), '_')}_$language';

  Future<void> _cleanupOldEntries() async {
    try {
      final cutoff =
          DateTime.now().subtract(const Duration(hours: _cacheDurationHours));
      final toDelete = <dynamic>[];
      for (final key in _cacheBox.keys) {
        final data = _cacheBox.get(key);
        if (data?['cached_at'] != null) {
          final cachedAt = DateTime.parse(data!['cached_at'] as String);
          if (cachedAt.isBefore(cutoff)) toDelete.add(key);
        }
      }
      for (final key in toDelete) {
        await _cacheBox.delete(key);
      }
      if (toDelete.isNotEmpty) {
        Logger.debug(
            '🗑️ [VERSE_CACHE] Cleaned up ${toDelete.length} expired entries');
      }
    } catch (e) {
      Logger.debug('⚠️ [VERSE_CACHE] Cleanup failed: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }
}

class CachedVerseData {
  final String text;
  final String localizedReference;
  final List<Map<String, dynamic>>? verses;

  const CachedVerseData({
    required this.text,
    required this.localizedReference,
    this.verses,
  });
}
