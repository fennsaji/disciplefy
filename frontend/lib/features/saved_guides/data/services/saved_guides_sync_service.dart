import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../datasources/saved_guides_remote_data_source.dart';

/// Mirrors the MemoryVerseSyncService pattern for saved-guides toggle operations.
///
/// Queue is stored as JSON string in Hive box 'saved_guides' under key
/// 'saved_guides_sync_queue'. Queue is processed in order; stops on first
/// failure to preserve operation ordering.
class SavedGuidesSyncService {
  static const String _boxName = 'saved_guides';
  static const String _queueKey = 'saved_guides_sync_queue';

  final SavedGuidesRemoteDataSource _remote;

  SavedGuidesSyncService({required SavedGuidesRemoteDataSource remote})
      : _remote = remote;

  Future<Either<Failure, Unit>> syncWithRemote() async {
    try {
      final queue = await getSyncQueue();
      if (queue.isEmpty) return const Right(unit);

      for (final operation in queue) {
        final type = operation['type'] as String?;
        if (type == 'toggle_save') {
          final guideId = operation['guideId'] as String;
          final save = operation['save'] as bool;
          try {
            await _remote.toggleSaveGuide(guideId: guideId, save: save);
          } catch (e) {
            Logger.warning(
                '[SavedGuidesSyncService] toggleSaveGuide failed for $guideId — stopping sync: $e');
            return Left(
                ServerFailure(message: 'Sync failed: $e', code: 'SYNC_FAILED'));
          }
        }
      }

      await clearSyncQueue();
      Logger.info(
          '[SavedGuidesSyncService] Sync complete — ${queue.length} operations processed');
      return const Right(unit);
    } catch (e) {
      Logger.error('[SavedGuidesSyncService] syncWithRemote error: $e');
      return Left(CacheFailure(message: 'Sync failed: $e'));
    }
  }

  Future<void> addToSyncQueue(Map<String, dynamic> operation) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      final box = Hive.box(_boxName);
      final queue = await getSyncQueue();
      queue.add({...operation, 'queuedAt': DateTime.now().toIso8601String()});
      await box.put(_queueKey, jsonEncode(queue));
    } catch (e) {
      Logger.error('[SavedGuidesSyncService] addToSyncQueue error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      final box = Hive.box(_boxName);
      final raw = box.get(_queueKey) as String?;
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearSyncQueue() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
      await Hive.box(_boxName).delete(_queueKey);
    } catch (e) {
      Logger.error('[SavedGuidesSyncService] clearSyncQueue error: $e');
    }
  }
}
