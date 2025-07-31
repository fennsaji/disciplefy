import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/daily_verse_entity.dart';
import '../../domain/repositories/daily_verse_repository.dart';
import '../services/daily_verse_api_service.dart';
import '../services/daily_verse_cache_service.dart';

/// Implementation of DailyVerseRepository with caching and offline support
class DailyVerseRepositoryImpl implements DailyVerseRepository {
  final DailyVerseApiService _apiService;
  final DailyVerseCacheService _cacheService;

  DailyVerseRepositoryImpl({
    required DailyVerseApiService apiService,
    required DailyVerseCacheService cacheService,
  }) : _apiService = apiService,
       _cacheService = cacheService;

  @override
  Future<Either<Failure, DailyVerseEntity>> getTodaysVerse() async => getDailyVerse(DateTime.now());

  @override
  Future<Either<Failure, DailyVerseEntity>> getDailyVerse(DateTime date) async {
    try {
      // Check if we should try cache first (offline or recent fetch)
      final shouldRefresh = await _cacheService.shouldRefresh();
      
      if (!shouldRefresh) {
        final cachedVerse = await _cacheService.getCachedVerse(date);
        if (cachedVerse != null) {
          return Right(cachedVerse);
        }
      }

      // Try to fetch from API
      final apiResult = await _apiService.getDailyVerse(date);
      
      return apiResult.fold(
        (failure) async {
          // API failed, try cache as fallback
          final cachedVerse = await _cacheService.getCachedVerse(date);
          if (cachedVerse != null) {
            return Right(cachedVerse);
          }
          return Left(failure);
        },
        (verse) async {
          // API success, cache the result
          try {
            await _cacheService.cacheVerse(verse);
          } on HiveError catch (e) {
            // Cache failure is non-critical, continue with API result
            if (kDebugMode) {
              print('Warning: Hive cache error: ${e.message}');
            }
          } on StorageException catch (e) {
            // Cache failure is non-critical, continue with API result
            if (kDebugMode) {
              print('Warning: Storage cache error: ${e.message}');
            }
          } catch (e) {
            // Cache failure is non-critical, continue with API result
            if (kDebugMode) {
              print('Warning: Failed to cache verse: $e');
            }
          }
          return Right(verse);
        },
      );

    } on SocketException catch (e) {
      return Left(NetworkFailure(
        message: 'Network connection failed: ${e.message}',
      ));
    } on HiveError catch (e) {
      return Left(CacheFailure(
        message: 'Cache operation failed: ${e.message}',
      ));
    } on StorageException catch (e) {
      return Left(CacheFailure(
        message: 'Storage error: ${e.message}',
      ));
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get daily verse: $e',
      ));
    }
  }

  @override
  Future<DailyVerseEntity?> getCachedVerse(DateTime date) async {
    try {
      return await _cacheService.getCachedVerse(date);
    } on HiveError {
      return null;
    } on StorageException {
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cacheVerse(DailyVerseEntity verse) async {
    try {
      await _cacheService.cacheVerse(verse);
    } on HiveError catch (e) {
      throw CacheException(
        message: 'Hive cache error: ${e.message}',
        code: 'CACHE_WRITE_ERROR',
      );
    } on StorageException catch (e) {
      throw CacheException(
        message: 'Storage error: ${e.message}',
        code: 'CACHE_WRITE_ERROR',
      );
    } catch (e) {
      throw CacheException(
        message: 'Failed to cache verse: $e',
        code: 'CACHE_WRITE_ERROR',
      );
    }
  }

  @override
  Future<VerseLanguage> getPreferredLanguage() async {
    try {
      return await _cacheService.getPreferredLanguage();
    } on StorageException {
      return VerseLanguage.english; // Default fallback
    } on HiveError {
      return VerseLanguage.english; // Default fallback
    } catch (e) {
      return VerseLanguage.english; // Default fallback
    }
  }

  @override
  Future<void> setPreferredLanguage(VerseLanguage language) async {
    try {
      await _cacheService.setPreferredLanguage(language);
    } on HiveError catch (e) {
      throw CacheException(
        message: 'Hive cache error: ${e.message}',
        code: 'CACHE_WRITE_ERROR',
      );
    } on StorageException catch (e) {
      throw CacheException(
        message: 'Storage error: ${e.message}',
        code: 'CACHE_WRITE_ERROR',
      );
    } catch (e) {
      throw CacheException(
        message: 'Failed to save preferred language: $e',
        code: 'CACHE_WRITE_ERROR',
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      return await _apiService.isServiceAvailable();
    } on SocketException {
      return false;
    } on ServerException {
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await _cacheService.getCacheStats();
    } on HiveError catch (e) {
      return {
        'error': 'Hive cache error: ${e.message}',
        'total_cached_verses': 0,
        'last_fetch': null,
        'preferred_language': 'English',
        'cache_size_bytes': 0,
      };
    } on StorageException catch (e) {
      return {
        'error': 'Storage error: ${e.message}',
        'total_cached_verses': 0,
        'last_fetch': null,
        'preferred_language': 'English',
        'cache_size_bytes': 0,
      };
    } catch (e) {
      return {
        'error': 'Failed to get cache stats: $e',
        'total_cached_verses': 0,
        'last_fetch': null,
        'preferred_language': 'English',
        'cache_size_bytes': 0,
      };
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _cacheService.clearCache();
    } on HiveError catch (e) {
      throw CacheException(
        message: 'Hive cache error: ${e.message}',
        code: 'CACHE_CLEAR_ERROR',
      );
    } on StorageException catch (e) {
      throw CacheException(
        message: 'Storage error: ${e.message}',
        code: 'CACHE_CLEAR_ERROR',
      );
    } catch (e) {
      throw CacheException(
        message: 'Failed to clear cache: $e',
        code: 'CACHE_CLEAR_ERROR',
      );
    }
  }
}

