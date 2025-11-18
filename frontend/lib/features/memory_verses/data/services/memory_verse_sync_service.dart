import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../datasources/memory_verse_local_datasource.dart';
import '../datasources/memory_verse_remote_datasource.dart';

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
      if (kDebugMode) {
        print('🔄 [SYNC] Starting sync...');
      }

      final syncQueue = await _localDataSource.getSyncQueue();

      if (syncQueue.isEmpty) {
        if (kDebugMode) {
          print('✅ [SYNC] Nothing to sync');
        }
        return const Right(unit);
      }

      // Process each queued operation
      bool hadFailure = false;

      for (final operation in syncQueue) {
        try {
          await _processSyncOperation(operation);
        } catch (e) {
          if (kDebugMode) {
            print('❌ [SYNC] Failed to sync operation: $e');
            print('⏸️ [SYNC] Stopping sync to preserve failed operations');
          }
          hadFailure = true;
          break; // Stop processing to preserve operation order
        }
      }

      // Only clear sync queue if all operations succeeded
      if (!hadFailure) {
        await _localDataSource.clearSyncQueue();
        await _localDataSource.updateLastSyncTime();

        if (kDebugMode) {
          print('✅ [SYNC] Sync completed - all operations synced successfully');
        }

        return const Right(unit);
      } else {
        if (kDebugMode) {
          print(
              '⚠️ [SYNC] Sync incomplete - failed operations remain queued for retry');
        }

        return const Left(
          ServerFailure(
            message: 'Sync failed - some operations could not be completed',
            code: 'SYNC_INCOMPLETE',
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SYNC] Sync failed: $e');
      }
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

    switch (type) {
      case 'add_from_daily':
        await _remoteDataSource.addVerseFromDaily(
          operation['daily_verse_id'] as String,
        );
        break;

      case 'add_manual':
        await _remoteDataSource.addVerseManually(
          verseReference: operation['verse_reference'] as String,
          verseText: operation['verse_text'] as String,
          language: operation['language'] as String?,
        );
        break;

      case 'submit_review':
        await _remoteDataSource.submitReview(
          memoryVerseId: operation['memory_verse_id'] as String,
          qualityRating: operation['quality_rating'] as int,
          timeSpentSeconds: operation['time_spent_seconds'] as int?,
        );
        break;

      case 'delete_verse':
        await _remoteDataSource.deleteVerse(
          operation['verse_id'] as String,
        );
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

  /// Adds an operation to the sync queue for later processing.
  Future<void> queueOperation(Map<String, dynamic> operation) async {
    await _localDataSource.addToSyncQueue(operation);
    if (kDebugMode) {
      print('📥 [SYNC] Operation queued: ${operation['type']}');
    }
  }
}
