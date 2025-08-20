import '../utils/logger.dart';

/// Coordinator service for managing language-related cache invalidation
/// across different parts of the application.
///
/// This service acts as a bridge between LanguagePreferenceService and RouterGuard
/// to eliminate circular dependencies while maintaining cache synchronization.
class LanguageCacheCoordinator {
  /// List of cache invalidation callbacks
  final List<VoidCallback> _cacheInvalidationCallbacks = [];

  /// Register a callback to be invoked when language cache needs invalidation
  void registerCacheInvalidationCallback(VoidCallback callback) {
    _cacheInvalidationCallbacks.add(callback);
    Logger.info(
      'Cache invalidation callback registered',
      tag: 'LANGUAGE_CACHE_COORDINATOR',
      context: {
        'total_callbacks': _cacheInvalidationCallbacks.length,
      },
    );
  }

  /// Unregister a callback from cache invalidation
  void unregisterCacheInvalidationCallback(VoidCallback callback) {
    _cacheInvalidationCallbacks.remove(callback);
    Logger.info(
      'Cache invalidation callback unregistered',
      tag: 'LANGUAGE_CACHE_COORDINATOR',
      context: {
        'total_callbacks': _cacheInvalidationCallbacks.length,
      },
    );
  }

  /// Invalidate all registered language caches
  /// This should be called when language preferences change
  void invalidateLanguageCaches() {
    Logger.info(
      'Invalidating all language caches',
      tag: 'LANGUAGE_CACHE_COORDINATOR',
      context: {
        'callbacks_to_invoke': _cacheInvalidationCallbacks.length,
      },
    );

    for (final callback in _cacheInvalidationCallbacks) {
      try {
        callback();
      } catch (e) {
        Logger.error(
          'Error invoking cache invalidation callback',
          tag: 'LANGUAGE_CACHE_COORDINATOR',
          error: e,
        );
      }
    }

    Logger.info(
      'All language caches invalidated successfully',
      tag: 'LANGUAGE_CACHE_COORDINATOR',
    );
  }

  /// Clear all registered callbacks (useful for testing or cleanup)
  void clearCallbacks() {
    final callbackCount = _cacheInvalidationCallbacks.length;
    _cacheInvalidationCallbacks.clear();

    Logger.info(
      'All cache invalidation callbacks cleared',
      tag: 'LANGUAGE_CACHE_COORDINATOR',
      context: {
        'cleared_callbacks': callbackCount,
      },
    );
  }
}

/// Callback signature for cache invalidation
typedef VoidCallback = void Function();
