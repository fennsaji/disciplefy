import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../datasources/memory_verse_local_datasource.dart';
import '../datasources/memory_verse_remote_datasource.dart';
import '../../../../core/utils/logger.dart';

/// Service responsible for synchronizing offline operations with remote server.
///
/// Processes queued operations (add verse, submit review, delete verse) and
/// syncs them to the remote server when connectivity is restored.
class MemoryVerseSyncService {
  final MemoryVerseLocalDataSource _localDataSource;
  final MemoryVerseRemoteDataSource _remoteDataSource;

  const MemoryVerseSyncService({
    required MemoryVerseLocalDataSource localDataSource,
    required MemoryVerseRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Syncs all queued operations with remote server.
  ///
  /// Processes operations in order and stops on first failure to preserve
  /// operation sequence. Only clears queue if all operations succeed.
  ///
  /// Returns [Right(unit)] if sync successful, [Left(Failure)] otherwise.
  Future<Either<Failure, Unit>> syncWithRemote() async {
    try {
      Logger.debug('🔄 [SYNC] Starting sync...');

      final syncQueue = await _localDataSource.getSyncQueue();

      if (syncQueue.isEmpty) {
        Logger.info('✅ [SYNC] Nothing to sync');
        return const Right(unit);
      }

      // Process each queued operation
      bool hadFailure = false;

      for (final operation in syncQueue) {
        try {
          await _processSyncOperation(operation);
        } catch (e) {
          if (kDebugMode) {
            Logger.error('❌ [SYNC] Failed to sync operation: $e');
            Logger.debug(
                '⏸️ [SYNC] Stopping sync to preserve failed operations');
          }
          hadFailure = true;
          break; // Stop processing to preserve operation order
        }
      }

      // Only clear sync queue if all operations succeeded
      if (!hadFailure) {
        await _localDataSource.clearSyncQueue();
        await _localDataSource.updateLastSyncTime();

        Logger.info(
            '✅ [SYNC] Sync completed - all operations synced successfully');

        return const Right(unit);
      } else {
        Logger.warning(
            '⚠️ [SYNC] Sync incomplete - failed operations remain queued for retry');

        return const Left(
          ServerFailure(
            message: 'Sync failed - some operations could not be completed',
            code: 'SYNC_INCOMPLETE',
          ),
        );
      }
    } catch (e) {
      Logger.error('❌ [SYNC] Sync failed: $e');
      return Left(ServerFailure(
          message: 'Sync failed: ${e.toString()}', code: 'SYNC_FAILED'));
    }
  }

  /// Processes a single sync operation based on its type.
  Future<void> _processSyncOperation(Map<String, dynamic> operation) async {
    // Validate that operation contains a valid 'type' field
    final typeValue = operation['type'];
    if (typeValue == null) {
      throw ArgumentError(
        'Sync operation missing required "type" field. Operation data: $operation',
      );
    }
    if (typeValue is! String) {
      throw ArgumentError(
        'Sync operation "type" must be a String, got ${typeValue.runtimeType}. '
        'Operation data: $operation',
      );
    }
    if (typeValue.isEmpty) {
      throw ArgumentError(
        'Sync operation "type" cannot be empty. Operation data: $operation',
      );
    }

    final type = typeValue;
    final operationId = operation['id']?.toString() ?? 'unknown';

    switch (type) {
      case 'add_from_daily':
        try {
          final dailyVerseId = _getRequiredString(
            operation,
            'daily_verse_id',
            operationId,
            type,
          );
          await _remoteDataSource.addVerseFromDaily(dailyVerseId);
        } catch (e, stackTrace) {
          _logOperationError(operationId, type, e, stackTrace);
          rethrow;
        }
        break;

      case 'add_manual':
        try {
          final verseReference = _getRequiredString(
            operation,
            'verse_reference',
            operationId,
            type,
          );
          final verseText = _getRequiredString(
            operation,
            'verse_text',
            operationId,
            type,
          );
          final language = _getOptionalString(operation, 'language');

          await _remoteDataSource.addVerseManually(
            verseReference: verseReference,
            verseText: verseText,
            language: language,
          );
        } catch (e, stackTrace) {
          _logOperationError(operationId, type, e, stackTrace);
          rethrow;
        }
        break;

      case 'submit_review':
        try {
          final memoryVerseId = _getRequiredString(
            operation,
            'memory_verse_id',
            operationId,
            type,
          );
          final qualityRating = _getRequiredInt(
            operation,
            'quality_rating',
            operationId,
            type,
          );
          final timeSpentSeconds = _getOptionalInt(
            operation,
            'time_spent_seconds',
          );

          await _remoteDataSource.submitReview(
            memoryVerseId: memoryVerseId,
            qualityRating: qualityRating,
            timeSpentSeconds: timeSpentSeconds,
          );
        } catch (e, stackTrace) {
          _logOperationError(operationId, type, e, stackTrace);
          rethrow;
        }
        break;

      case 'delete_verse':
        try {
          final verseId = _getRequiredString(
            operation,
            'verse_id',
            operationId,
            type,
          );
          await _remoteDataSource.deleteVerse(verseId);
        } catch (e, stackTrace) {
          _logOperationError(operationId, type, e, stackTrace);
          rethrow;
        }
        break;

      default:
        // Throw exception for unknown operation types to prevent silent failures
        throw UnsupportedError(
          'Unknown sync operation type: "$type". '
          'Supported types: add_from_daily, add_manual, submit_review, delete_verse. '
          'Operation data: $operation',
        );
    }
  }

  /// Safely extracts a required String field from operation data.
  String _getRequiredString(
    Map<String, dynamic> operation,
    String fieldName,
    String operationId,
    String operationType,
  ) {
    final value = operation[fieldName];

    if (value == null) {
      throw ArgumentError(
        'Missing required field "$fieldName" in sync operation. '
        'Operation ID: $operationId, Type: $operationType, Data: $operation',
      );
    }

    if (value is! String) {
      throw ArgumentError(
        'Field "$fieldName" must be a String, got ${value.runtimeType}. '
        'Operation ID: $operationId, Type: $operationType, Value: $value',
      );
    }

    if (value.isEmpty) {
      throw ArgumentError(
        'Field "$fieldName" cannot be empty. '
        'Operation ID: $operationId, Type: $operationType',
      );
    }

    return value;
  }

  /// Safely extracts a required int field from operation data.
  int _getRequiredInt(
    Map<String, dynamic> operation,
    String fieldName,
    String operationId,
    String operationType,
  ) {
    final value = operation[fieldName];

    if (value == null) {
      throw ArgumentError(
        'Missing required field "$fieldName" in sync operation. '
        'Operation ID: $operationId, Type: $operationType, Data: $operation',
      );
    }

    if (value is! int) {
      throw ArgumentError(
        'Field "$fieldName" must be an int, got ${value.runtimeType}. '
        'Operation ID: $operationId, Type: $operationType, Value: $value',
      );
    }

    return value;
  }

  /// Safely extracts an optional String field from operation data.
  String? _getOptionalString(
    Map<String, dynamic> operation,
    String fieldName,
  ) {
    final value = operation[fieldName];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      Logger.warning(
        '⚠️ [SYNC] Optional field "$fieldName" has wrong type '
        '(expected String, got ${value.runtimeType}). Using null.',
      );
      return null;
    }

    return value.isEmpty ? null : value;
  }

  /// Safely extracts an optional int field from operation data.
  int? _getOptionalInt(
    Map<String, dynamic> operation,
    String fieldName,
  ) {
    final value = operation[fieldName];

    if (value == null) {
      return null;
    }

    if (value is! int) {
      Logger.warning(
        '⚠️ [SYNC] Optional field "$fieldName" has wrong type '
        '(expected int, got ${value.runtimeType}). Using null.',
      );
      return null;
    }

    return value;
  }

  /// Logs detailed error information for failed sync operations.
  void _logOperationError(
    String operationId,
    String operationType,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      Logger.error('❌ [SYNC] Operation failed:');
      Logger.debug('   Operation ID: $operationId');
      Logger.debug('   Operation Type: $operationType');
      Logger.debug('   Error: $error');
      Logger.debug('   Stack trace: $stackTrace');
    }
  }

  /// Adds an operation to the sync queue for later processing.
  Future<void> queueOperation(Map<String, dynamic> operation) async {
    await _localDataSource.addToSyncQueue(operation);
    Logger.debug('📥 [SYNC] Operation queued: ${operation['type']}');
  }
}
