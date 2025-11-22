import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/study_guide.dart';

/// Repository interface for study guide operations.
///
/// This abstract class defines the contract for study guide data operations,
/// following Clean Architecture principles with proper error handling.
abstract class StudyRepository {
  /// Generates a study guide from a verse reference or topic.
  ///
  /// [input] The verse reference or topic to generate a study guide for.
  /// [inputType] The type of input ('scripture' or 'topic').
  /// [topicDescription] Optional description providing additional context for topics.
  /// [language] The language code for the study guide (defaults to 'en').
  ///
  /// Returns an [Either] containing either a [Failure] or [StudyGuide].
  Future<Either<Failure, StudyGuide>> generateStudyGuide({
    required String input,
    required String inputType,
    String? topicDescription,
    required String language,
  });

  /// Retrieves cached study guides for offline access.
  ///
  /// Returns a list of previously generated study guides.
  Future<List<StudyGuide>> getCachedStudyGuides();

  /// Caches a study guide for offline access.
  ///
  /// [studyGuide] The study guide to cache.
  /// Returns true if the operation was successful.
  Future<bool> cacheStudyGuide(StudyGuide studyGuide);

  /// Clears the study guide cache.
  ///
  /// Returns true if the operation was successful.
  Future<bool> clearCache();
}
