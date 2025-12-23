import '../entities/reflection_response.dart';
import '../entities/study_mode.dart';

/// Abstract repository for managing study reflections.
///
/// This interface follows Clean Architecture principles by defining
/// the contract for reflection data operations without implementation details.
abstract class ReflectionsRepository {
  /// Saves a reflection session.
  ///
  /// Returns the saved [ReflectionSession] with generated ID.
  /// Throws on authentication or network errors.
  Future<ReflectionSession> saveReflection({
    required String studyGuideId,
    required StudyMode studyMode,
    required List<ReflectionResponse> responses,
    required int timeSpentSeconds,
    DateTime? completedAt,
  });

  /// Gets a reflection by its ID.
  ///
  /// Returns null if not found.
  Future<ReflectionSession?> getReflection(String reflectionId);

  /// Gets a reflection for a specific study guide.
  ///
  /// Returns null if no reflection exists for this guide.
  Future<ReflectionSession?> getReflectionForGuide(String studyGuideId);

  /// Lists user's reflections with pagination.
  ///
  /// Returns a paginated list of reflection sessions.
  Future<ReflectionListResult> listReflections({
    int page = 1,
    int perPage = 20,
    StudyMode? studyMode,
  });

  /// Deletes a reflection by ID.
  Future<void> deleteReflection(String reflectionId);

  /// Gets reflection statistics for the current user.
  Future<ReflectionStats> getReflectionStats();
}

/// Result of a paginated reflection list query.
class ReflectionListResult {
  final List<ReflectionSession> reflections;
  final int total;
  final int page;
  final int perPage;
  final bool hasMore;

  const ReflectionListResult({
    required this.reflections,
    required this.total,
    required this.page,
    required this.perPage,
    required this.hasMore,
  });
}

/// User's reflection statistics.
class ReflectionStats {
  final int totalReflections;
  final int totalTimeSpentSeconds;
  final Map<StudyMode, int> reflectionsByMode;
  final List<String> mostCommonLifeAreas;

  const ReflectionStats({
    required this.totalReflections,
    required this.totalTimeSpentSeconds,
    required this.reflectionsByMode,
    required this.mostCommonLifeAreas,
  });

  /// Total time formatted as a readable string.
  String get formattedTotalTime {
    final hours = totalTimeSpentSeconds ~/ 3600;
    final minutes = (totalTimeSpentSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Average time per reflection in minutes.
  int get averageTimeMinutes {
    if (totalReflections == 0) return 0;
    return (totalTimeSpentSeconds / totalReflections / 60).round();
  }
}
