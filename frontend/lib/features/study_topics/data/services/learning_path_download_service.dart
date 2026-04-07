import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/token_failures.dart';
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

  /// Returns all in-memory download models (synchronous; populated after init).
  List<LearningPathDownloadModel> get cachedDownloads => _cache.values.toList();

  /// Returns all persisted download models (for the Settings screen).
  Future<List<LearningPathDownloadModel>> getAllDownloads() async {
    final box = await _box();
    return box.values.map((v) => LearningPathDownloadModel.fromMap(v)).toList();
  }

  /// Deletes the persisted download record for [learningPathId].
  Future<void> deleteDownload(String learningPathId) async {
    await cancelDownload(learningPathId);
  }

  /// Adds a single topic to an existing download job and starts the loop.
  ///
  /// If the topic is already in the model and done, this is a no-op.
  /// If it is failed or pending, it is reset to pending.
  /// If it is not in the model at all, it is appended.
  /// No-op while a download is already actively running.
  Future<void> queueSingleTopic(
      String pathId, LearningPathTopicDownload topic) async {
    final model = getDownload(pathId);
    if (model == null) return;
    if (model.status == PathDownloadStatus.downloading ||
        model.status == PathDownloadStatus.queued) {
      return;
    }

    final existingIndex =
        model.topics.indexWhere((t) => t.topicId == topic.topicId);

    if (existingIndex >= 0 &&
        model.topics[existingIndex].status == TopicDownloadStatus.done) {
      return; // already downloaded
    }

    List<LearningPathTopicDownload> updatedTopics;
    if (existingIndex >= 0) {
      updatedTopics = List.from(model.topics);
      updatedTopics[existingIndex] = model.topics[existingIndex]
          .copyWith(status: TopicDownloadStatus.pending);
    } else {
      updatedTopics = [
        ...model.topics,
        topic.copyWith(status: TopicDownloadStatus.pending),
      ];
    }

    final updated = model.copyWith(
      topics: updatedTopics,
      totalCount: updatedTopics.length,
      status: PathDownloadStatus.downloading,
    );
    await _persist(updated);
    _emit(updated);
    unawaited(processDownloadLoop(updated));
  }

  /// Merges [newTopics] into an existing download model without overwriting
  /// already-completed topics, then starts the loop for the new ones.
  ///
  /// Falls back to [startDownload] if no model exists for [pathId].
  /// No-op if the path is already actively downloading or queued.
  Future<void> queueAdditionalTopics({
    required String pathId,
    required String pathTitle,
    required String language,
    required List<LearningPathTopicDownload> newTopics,
  }) async {
    final existing = getDownload(pathId);
    if (existing == null) {
      await startDownload(
        learningPathId: pathId,
        learningPathTitle: pathTitle,
        language: language,
        topics: newTopics,
      );
      return;
    }

    if (existing.status == PathDownloadStatus.downloading ||
        existing.status == PathDownloadStatus.queued) {
      return;
    }

    // Merge: preserve done topics, reset/add new ones.
    final updatedTopics = List<LearningPathTopicDownload>.from(existing.topics);
    for (final topic in newTopics) {
      final idx = updatedTopics.indexWhere((t) => t.topicId == topic.topicId);
      if (idx >= 0) {
        if (updatedTopics[idx].status != TopicDownloadStatus.done) {
          updatedTopics[idx] =
              topic.copyWith(status: TopicDownloadStatus.pending);
        }
      } else {
        updatedTopics.add(topic.copyWith(status: TopicDownloadStatus.pending));
      }
    }

    final updated = existing.copyWith(
      topics: updatedTopics,
      totalCount: updatedTopics.length,
      status: PathDownloadStatus.downloading,
    );
    await _persist(updated);
    _emit(updated);
    unawaited(processDownloadLoop(updated));
  }

  /// Retries a single failed topic, resetting it to pending and resuming the loop.
  ///
  /// No-op if the path is already actively downloading or the topic is not failed.
  Future<void> retryTopic(String pathId, String topicId) async {
    final model = getDownload(pathId);
    if (model == null) return;
    if (model.status == PathDownloadStatus.downloading ||
        model.status == PathDownloadStatus.queued) {
      return;
    }

    final updatedTopics = model.topics
        .map((t) =>
            t.topicId == topicId && t.status == TopicDownloadStatus.failed
                ? t.copyWith(status: TopicDownloadStatus.pending)
                : t)
        .toList();

    final updated = model.copyWith(
      topics: updatedTopics,
      status: PathDownloadStatus.downloading,
    );
    await _persist(updated);
    _emit(updated);
    unawaited(processDownloadLoop(updated));
  }

  /// Removes a single downloaded guide from a path.
  ///
  /// Deletes the guide from local storage, marks the topic as pending in the
  /// download model, and decrements [completedCount]. If no guides remain,
  /// the entire path record is removed.
  Future<void> deleteTopic(String pathId, String guideId) async {
    await _localDataSource.deleteStudyGuide(guideId);

    final box = await _box();
    final raw = box.get(pathId);
    if (raw == null) return;

    final model = LearningPathDownloadModel.fromMap(raw);

    final updatedTopics = model.topics.map((t) {
      if (t.cachedGuideId == guideId) {
        return LearningPathTopicDownload(
          topicId: t.topicId,
          topicTitle: t.topicTitle,
          inputType: t.inputType,
          description: t.description,
          studyMode: t.studyMode,
          status: TopicDownloadStatus.pending,
        );
      }
      return t;
    }).toList();

    final newCompletedCount =
        updatedTopics.where((t) => t.status == TopicDownloadStatus.done).length;

    if (newCompletedCount == 0) {
      await deleteDownload(pathId);
      return;
    }

    final updated = model.copyWith(
      topics: updatedTopics,
      completedCount: newCompletedCount,
    );
    await _persist(updated);
    _emit(updated);
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

      final params = StudyGenerationParams(
        input: topic.topicTitle,
        inputType: topic.inputType,
        topicDescription:
            topic.description.isNotEmpty ? topic.description : null,
        language: current.language,
      );

      var result = await _generateStudyGuide(params);

      // On rate limit: wait the required duration and retry once.
      if (result.isLeft()) {
        final failure = result.fold((f) => f, (_) => null);
        if (failure is RateLimitFailure) {
          final wait = failure.retryAfter ?? const Duration(seconds: 60);
          Logger.info(
              '[DOWNLOAD] Rate limited — waiting ${wait.inSeconds}s before retry');
          await Future<void>.delayed(wait);
          result = await _generateStudyGuide(params);
        }
      }

      // On insufficient tokens: pause the path and stop the loop.
      if (result.isLeft()) {
        final failure = result.fold((f) => f, (_) => null);
        if (failure is InsufficientTokensFailure) {
          Logger.info(
              '[DOWNLOAD] Insufficient tokens — pausing download for ${current.learningPathId}');
          _isPaused = true;
          final paused = current.copyWith(
            topics: updatedTopics,
            status: PathDownloadStatus.paused,
          );
          await _persist(paused);
          _emit(paused);
          AndroidDownloadNotificationService.stopForeground();
          return;
        }
      }

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
