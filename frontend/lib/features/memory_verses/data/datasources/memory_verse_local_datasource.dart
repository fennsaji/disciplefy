import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../models/memory_verse_model.dart';

/// Local data source for caching memory verses using Hive.
///
/// Provides offline-first storage for memory verses with:
/// - Persistent storage for verses and review data
/// - Fast local access without network calls
/// - Offline review support
/// - Sync queue for pending changes
class MemoryVerseLocalDataSource {
  static const String _boxName = 'memory_verses_cache';
  static const String _versesKey = 'verses_list';
  static const String _syncQueueKey = 'sync_queue';
  static const String _lastSyncKey = 'last_sync_timestamp';

  /// Hive box for storing cached memory verses
  Box<String>? _cacheBox;

  /// Flag to prevent concurrent initialization attempts
  bool _isInitializing = false;

  /// Initialize the Hive box for caching
  Future<void> initialize() async {
    // If already initialized, skip
    if (_cacheBox != null && _cacheBox!.isOpen) {
      if (kDebugMode) {
        print('ℹ️ [MEMORY VERSES CACHE] Hive box already initialized');
      }
      return;
    }

    // Prevent concurrent initialization
    if (_isInitializing) {
      if (kDebugMode) {
        print(
            '⏳ [MEMORY VERSES CACHE] Initialization already in progress, waiting...');
      }
      // Wait for initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;

    try {
      _cacheBox = await Hive.openBox<String>(_boxName);
      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Hive box initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Failed to initialize Hive box: $e');
        print(
            '🔄 [MEMORY VERSES CACHE] Attempting to delete corrupted box and retry...');
      }

      // Try to delete corrupted box and retry
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _cacheBox = await Hive.openBox<String>(_boxName);
        if (kDebugMode) {
          print('✅ [MEMORY VERSES CACHE] Hive box recovered after deletion');
        }
      } catch (recoveryError) {
        if (kDebugMode) {
          print('❌ [MEMORY VERSES CACHE] Recovery failed: $recoveryError');
        }
        rethrow;
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Ensures the Hive box is initialized before use (lazy initialization)
  Future<Box<String>> _ensureInitialized() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      if (kDebugMode) {
        print(
            '⚠️ [MEMORY VERSES CACHE] Box not initialized, initializing now...');
      }
      await initialize();
    }

    if (_cacheBox == null) {
      throw Exception(
          'Hive box failed to initialize after multiple attempts. Please restart the app.');
    }

    return _cacheBox!;
  }

  /// Gets all cached memory verses
  ///
  /// Returns empty list if no cache exists
  Future<List<MemoryVerseModel>> getAllCachedVerses() async {
    try {
      final box = await _ensureInitialized();

      final versesJson = box.get(_versesKey);
      if (versesJson == null) {
        return [];
      }

      final List<dynamic> versesList = jsonDecode(versesJson);
      return versesList
          .map(
              (json) => MemoryVerseModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error getting cached verses: $e');
      }
      return [];
    }
  }

  /// Gets cached verses that are due for review
  ///
  /// Filters locally by next_review_date <= now
  Future<List<MemoryVerseModel>> getDueCachedVerses() async {
    try {
      final allVerses = await getAllCachedVerses();
      final now = DateTime.now();

      return allVerses
          .where((verse) =>
              verse.nextReviewDate.isBefore(now) ||
              verse.nextReviewDate.isAtSameMomentAs(now))
          .toList()
        ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error getting due verses: $e');
      }
      return [];
    }
  }

  /// Gets a specific verse by ID from cache
  Future<MemoryVerseModel?> getCachedVerseById(String id) async {
    try {
      final allVerses = await getAllCachedVerses();
      return allVerses.firstWhere(
        (verse) => verse.id == id,
        orElse: () => throw Exception('Verse not found'),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error getting verse by ID: $e');
      }
      return null;
    }
  }

  /// Caches a list of memory verses (replaces entire cache)
  Future<void> cacheVerses(List<MemoryVerseModel> verses) async {
    try {
      final box = await _ensureInitialized();

      final versesJson = jsonEncode(
        verses.map((verse) => verse.toJson()).toList(),
      );
      await box.put(_versesKey, versesJson);

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Cached ${verses.length} verses');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error caching verses: $e');
      }
      rethrow;
    }
  }

  /// Adds or updates a single verse in cache
  Future<void> cacheVerse(MemoryVerseModel verse) async {
    try {
      final allVerses = await getAllCachedVerses();

      // Remove existing verse with same ID if present
      allVerses.removeWhere((v) => v.id == verse.id);

      // Add the new/updated verse
      allVerses.add(verse);

      // Save back to cache
      await cacheVerses(allVerses);

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Cached verse: ${verse.verseReference}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error caching verse: $e');
      }
      rethrow;
    }
  }

  /// Removes a verse from cache
  Future<void> removeVerse(String id) async {
    try {
      final allVerses = await getAllCachedVerses();
      allVerses.removeWhere((verse) => verse.id == id);
      await cacheVerses(allVerses);

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Removed verse: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error removing verse: $e');
      }
      rethrow;
    }
  }

  /// Adds a pending operation to the sync queue (for offline support)
  ///
  /// Operations are stored as JSON and processed when online
  Future<void> addToSyncQueue(Map<String, dynamic> operation) async {
    try {
      final box = await _ensureInitialized();

      final queueJson = box.get(_syncQueueKey) ?? '[]';
      final List<dynamic> queue = jsonDecode(queueJson);

      queue.add({
        ...operation,
        'queued_at': DateTime.now().toIso8601String(),
      });

      await box.put(_syncQueueKey, jsonEncode(queue));

      if (kDebugMode) {
        print(
            '✅ [MEMORY VERSES CACHE] Added to sync queue: ${operation['type']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error adding to sync queue: $e');
      }
      rethrow;
    }
  }

  /// Gets all pending operations from the sync queue
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      final box = await _ensureInitialized();

      final queueJson = box.get(_syncQueueKey) ?? '[]';
      final List<dynamic> queue = jsonDecode(queueJson);

      return queue.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error getting sync queue: $e');
      }
      return [];
    }
  }

  /// Clears the sync queue after successful sync
  Future<void> clearSyncQueue() async {
    try {
      final box = await _ensureInitialized();

      await box.put(_syncQueueKey, '[]');

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Sync queue cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error clearing sync queue: $e');
      }
      rethrow;
    }
  }

  /// Updates the last sync timestamp
  Future<void> updateLastSyncTime() async {
    try {
      final box = await _ensureInitialized();

      await box.put(_lastSyncKey, DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Last sync time updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error updating last sync time: $e');
      }
    }
  }

  /// Gets the last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    try {
      final box = await _ensureInitialized();

      final timestampStr = box.get(_lastSyncKey);
      if (timestampStr == null) return null;

      return DateTime.parse(timestampStr);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error getting last sync time: $e');
      }
      return null;
    }
  }

  /// Clears all cached data (for logout or reset)
  Future<void> clearCache() async {
    try {
      final box = await _ensureInitialized();

      await box.clear();

      if (kDebugMode) {
        print('✅ [MEMORY VERSES CACHE] Cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [MEMORY VERSES CACHE] Error clearing cache: $e');
      }
      rethrow;
    }
  }

  /// Closes the Hive box (cleanup)
  Future<void> dispose() async {
    await _cacheBox?.close();
    _cacheBox = null;
  }
}
