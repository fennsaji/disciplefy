import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/study_guide.dart';

/// Abstract contract for local study guide operations.
abstract class StudyLocalDataSource {
  /// Gets all cached study guides.
  Future<List<StudyGuide>> getCachedStudyGuides();

  /// Caches a study guide locally.
  Future<bool> cacheStudyGuide(StudyGuide studyGuide);

  /// Clears all cached study guides.
  Future<bool> clearCache();
}

/// Implementation of StudyLocalDataSource using Hive.
class StudyLocalDataSourceImpl implements StudyLocalDataSource {
  /// Box name for caching study guides.
  static const String _studyGuidesBoxName = 'study_guides';

  /// Creates a new StudyLocalDataSourceImpl instance.
  StudyLocalDataSourceImpl();

  @override
  Future<List<StudyGuide>> getCachedStudyGuides() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }

      final box = Hive.box(_studyGuidesBoxName);
      final studyGuides = <StudyGuide>[];

      for (final key in box.keys) {
        final data = box.get(key) as Map<dynamic, dynamic>?;
        if (data != null) {
          try {
            final studyGuide = _parseStudyGuideFromCache(data);
            studyGuides.add(studyGuide);
          } catch (e) {
            // Skip invalid cached entries
            continue;
          }
        }
      }

      // Sort by creation date (newest first)
      studyGuides.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Return only the most recent guides
      return studyGuides.take(AppConstants.MAX_STUDY_GUIDES_CACHE).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> cacheStudyGuide(StudyGuide studyGuide) async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }

      final box = Hive.box(_studyGuidesBoxName);
      final data = _convertStudyGuideToMap(studyGuide);

      await box.put(studyGuide.id, data);

      // Cleanup old entries if cache exceeds limit
      if (box.length > AppConstants.MAX_STUDY_GUIDES_CACHE) {
        final allGuides = await getCachedStudyGuides();
        final oldestGuides =
            allGuides.skip(AppConstants.MAX_STUDY_GUIDES_CACHE);

        for (final guide in oldestGuides) {
          await box.delete(guide.id);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      if (!Hive.isBoxOpen(_studyGuidesBoxName)) {
        await Hive.openBox(_studyGuidesBoxName);
      }

      final box = Hive.box(_studyGuidesBoxName);
      await box.clear();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a study guide from cached data.
  StudyGuide _parseStudyGuideFromCache(Map<dynamic, dynamic> data) =>
      StudyGuide(
        id: data['id'] as String,
        input: data['input'] as String,
        inputType: data['inputType'] as String,
        summary: data['summary'] as String,
        interpretation:
            data['interpretation'] as String? ?? 'No interpretation available',
        context: data['context'] as String,
        relatedVerses: (data['relatedVerses'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        reflectionQuestions: (data['reflectionQuestions'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        prayerPoints: (data['prayerPoints'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        language: data['language'] as String? ?? AppConstants.DEFAULT_LANGUAGE,
        createdAt: DateTime.parse(data['createdAt'] as String),
        userId: data['userId'] as String?,
      );

  /// Converts a study guide to a map for caching.
  Map<String, dynamic> _convertStudyGuideToMap(StudyGuide studyGuide) => {
        'id': studyGuide.id,
        'input': studyGuide.input,
        'inputType': studyGuide.inputType,
        'summary': studyGuide.summary,
        'interpretation': studyGuide.interpretation,
        'context': studyGuide.context,
        'relatedVerses': studyGuide.relatedVerses,
        'reflectionQuestions': studyGuide.reflectionQuestions,
        'prayerPoints': studyGuide.prayerPoints,
        'language': studyGuide.language,
        'createdAt': studyGuide.createdAt.toIso8601String(),
        'userId': studyGuide.userId,
      };
}
