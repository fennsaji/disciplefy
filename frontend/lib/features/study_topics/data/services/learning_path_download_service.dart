import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/services/android_download_notification_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../study_generation/data/datasources/study_local_data_source.dart';
import '../../../study_generation/domain/usecases/generate_study_guide.dart';
import '../models/learning_path_download_model.dart';

/// Service responsible for managing offline download of learning path topics.
///
/// Downloads each topic as a study guide, persists progress to Hive, and
/// exposes per-path streams so the UI can react to state changes.
class LearningPathDownloadService {
  static const String _boxName = 'learning_path_downloads';

  final GenerateStudyGuide _generateStudyGuide;
  final StudyLocalDataSource _localDataSource;

  // Per-path StreamControllers; broadcast so multiple UI listeners are fine.
  final Map<String, StreamController<LearningPathDownloadModel>> _controllers =
      {};
  final Map<String, LearningPathDownloadModel> _cache = {};
  bool _isPaused = false;

  /// Creates a new [LearningPathDownloadService].
  ///
  /// [generateStudyGuide] Use case for generating individual study guides.
  /// [localDataSource] Local data source for caching generated guides.
  LearningPathDownloadService({
    required GenerateStudyGuide generateStudyGuide,
    required StudyLocalDataSource localDataSource,
  })  : _generateStudyGuide = generateStudyGuide,
        _localDataSource = localDataSource;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Builds a new download job model without persisting it.
  LearningPathDownloadModel buildDownloadJob({
    required String learningPathId,
    required String learningPathTitle,
    required String language,
    required List<LearningPathTopicDownload> topics,
  }) {
    return LearningPathDownloadModel(
      learningPathId: learningPathId,
      learningPathTitle: learningPathTitle,
      language: language,
      topics: topics
          .map((t) => t.copyWith(status: TopicDownloadStatus.pending))
          .toList(),
      status: PathDownloadStatus.queued,
      queuedAt: DateTime.now(),
      completedCount: 0,
      totalCount: topics.length,
    );
  }

  /// Starts downloading all topics in a learning path.
  ///
  /// Idempotent: if the path is already downloading or queued, this is a no-op.
  Future<void> startDownload({
    required String learningPathId,
    required String learningPathTitle,
    required String language,
    required List<LearningPathTopicDownload> topics,
  }) async {
    // Idempotent: if already downloading this path, do nothing.
    final existing = getDownload(learningPathId);
    if (existing != null &&
        (existing.status == PathDownloadStatus.downloading ||
            existing.status == PathDownloadStatus.queued)) {
      Logger.info('[DOWNLOAD] Already active: $learningPathId');
      return;
    }

    final model = buildDownloadJob(
      learningPathId: learningPathId,
      learningPathTitle: learningPathTitle,
      language: language,
      topics: topics,
    );

    await _persist(model);
    _emit(model);

    // Run download loop without blocking the caller.
    unawaited(processDownloadLoop(model));
  }

  /// Pauses an active download for the given learning path.
  Future<void> pauseDownload(String learningPathId) async {
    _isPaused = true;
    final model = getDownload(learningPathId);
    if (model == null) return;
    final updated = model.copyWith(status: PathDownloadStatus.paused);
    await _persist(updated);
    _emit(updated);
  }

  /// Cancels and removes the download for the given learning path.
  Future<void> cancelDownload(String learningPathId) async {
    _isPaused = true;
    final box = await _box();
    await box.delete(learningPathId);
    _cache.remove(learningPathId);
    _controllers[learningPathId]?.close();
    _controllers.remove(learningPathId);
  }

  /// Returns a broadcast stream of download state updates for [learningPathId].
  Stream<LearningPathDownloadModel> watchDownload(String learningPathId) {
    _controllers[learningPathId] ??=
        StreamController<LearningPathDownloadModel>.broadcast();
    return _controllers[learningPathId]!.stream;
  }

  /// Returns the current in-memory download state, or null if not found.
  LearningPathDownloadModel? getDownload(String learningPathId) {
    return _cache[learningPathId];
  }

  /// Returns all persisted download models (for the Settings screen).
  Future<List<LearningPathDownloadModel>> getAllDownloads() async {
    final box = await _box();
    return box.values.map((v) => LearningPathDownloadModel.fromMap(v)).toList();
  }

  /// Deletes the persisted download record for [learningPathId].
  Future<void> deleteDownload(String learningPathId) async {
    await cancelDownload(learningPathId);
  }

  // ---------------------------------------------------------------------------
  // Download loop (internal, but package-visible for testing)
  // ---------------------------------------------------------------------------

  /// Runs the sequential topic download loop for the given [model].
  ///
  /// Visible for testing — callers should normally use [startDownload].
  Future<void> processDownloadLoop(LearningPathDownloadModel model) async {
    _isPaused = false;
    var current = model.copyWith(status: PathDownloadStatus.downloading);
    await _persist(current);
    _emit(current);
    await AndroidDownloadNotificationService.startForeground(
        current.learningPathTitle);

    for (var i = 0; i < current.topics.length; i++) {
      if (_isPaused) {
        Logger.info(
            '[DOWNLOAD] Paused at topic $i for ${current.learningPathId}');
        return;
      }

      final topic = current.topics[i];
      if (topic.status == TopicDownloadStatus.done) continue;

      // Mark as downloading
      final updatedTopics =
          List<LearningPathTopicDownload>.from(current.topics);
      updatedTopics[i] =
          topic.copyWith(status: TopicDownloadStatus.downloading);
      current = current.copyWith(topics: updatedTopics);
      await _persist(current);
      _emit(current);

      final result = await _generateStudyGuide(
        StudyGenerationParams(
          input: topic.topicTitle,
          inputType: topic.inputType,
          topicDescription:
              topic.description.isNotEmpty ? topic.description : null,
          language: current.language,
        ),
      );

      result.fold(
        (failure) {
          Logger.error(
              '[DOWNLOAD] Topic failed: ${topic.topicTitle} — ${failure.message}');
          updatedTopics[i] = topic.copyWith(status: TopicDownloadStatus.failed);
        },
        (guide) {
          Logger.info('[DOWNLOAD] Topic done: ${topic.topicTitle}');
          updatedTopics[i] = topic.copyWith(
            status: TopicDownloadStatus.done,
            cachedGuideId: guide.id,
          );
          // Cache defensively in case download runs without going through BLoC.
          unawaited(_localDataSource.cacheStudyGuide(guide));
        },
      );

      final doneCount = updatedTopics
          .where((t) => t.status == TopicDownloadStatus.done)
          .length;
      current =
          current.copyWith(topics: updatedTopics, completedCount: doneCount);
      await _persist(current);
      _emit(current);
      await AndroidDownloadNotificationService.updateProgress(
        pathTitle: current.learningPathTitle,
        completed: current.completedCount,
        total: current.totalCount,
      );
    }

    // Determine final status
    final hasAnyDone =
        current.topics.any((t) => t.status == TopicDownloadStatus.done);
    final allDone =
        current.topics.every((t) => t.status == TopicDownloadStatus.done);
    final finalStatus = allDone
        ? PathDownloadStatus.completed
        : (hasAnyDone
            ? PathDownloadStatus.completed
            : PathDownloadStatus.failed);

    current = current.copyWith(status: finalStatus);
    await _persist(current);
    _emit(current);

    if (finalStatus == PathDownloadStatus.completed) {
      await AndroidDownloadNotificationService.completeDownload(
        current.learningPathTitle,
        current.completedCount,
      );
    } else {
      AndroidDownloadNotificationService.stopForeground();
    }

    Logger.info(
        '[DOWNLOAD] Loop finished for ${current.learningPathId}: $finalStatus '
        '(${current.completedCount}/${current.totalCount})');
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<Box<Map>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<Map>(_boxName);
    return await Hive.openBox<Map>(_boxName);
  }

  Future<void> _persist(LearningPathDownloadModel model) async {
    _cache[model.learningPathId] = model;
    final box = await _box();
    await box.put(model.learningPathId, model.toMap());
  }

  void _emit(LearningPathDownloadModel model) {
    _cache[model.learningPathId] = model;
    _controllers[model.learningPathId]?.add(model);
  }

  /// Loads all persisted downloads into the in-memory cache.
  ///
  /// Should be called once on app start before using the service.
  Future<void> initialize() async {
    final box = await _box();
    for (final value in box.values) {
      try {
        final model = LearningPathDownloadModel.fromMap(value);
        _cache[model.learningPathId] = model;
      } catch (e) {
        Logger.error('[DOWNLOAD] Failed to restore download: $e');
      }
    }
  }
}
