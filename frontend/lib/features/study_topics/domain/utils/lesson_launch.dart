import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

/// The only builder of a path-lesson URL. Lesson number = 1-based index of
/// [topic] in [path.topics] ordered by position.
String buildLessonLaunchLocation({
  required LearningPathDetail path,
  required LearningPathTopic topic,
  required StudyMode mode,
  required String language,
  String source = 'learningPath',
}) {
  final ordered = [...path.topics]
    ..sort((a, b) => a.position.compareTo(b.position));
  final index = ordered.indexWhere((t) => t.topicId == topic.topicId);
  return buildLessonLocation(
    input: topic.title,
    inputType: topic.inputType,
    topicId: topic.topicId,
    description: topic.description,
    pathDescription: path.description,
    discipleLevel: path.discipleLevel,
    ref: LessonRef(
      pathId: path.id,
      pathTitle: path.displayTitle,
      lessonNumber: index < 0 ? 1 : index + 1,
      lessonTotal: ordered.length,
    ),
    mode: mode,
    language: language,
    source: source,
  );
}

/// Study-guide URL for one lesson of a path. Every path-lesson launcher goes
/// through here so the query keys stay identical.
String buildLessonLocation({
  required String input,
  required String inputType,
  required String topicId,
  required String description,
  required String pathDescription,
  required String discipleLevel,
  required LessonRef ref,
  required StudyMode mode,
  required String language,
  String source = 'learningPath',
}) {
  final query = <String, String>{
    'input': input,
    'type': inputType,
    'language': language,
    'mode': mode.name,
    'source': source,
    if (topicId.isNotEmpty) 'topic_id': topicId,
    if (description.isNotEmpty) 'description': description,
    if (pathDescription.isNotEmpty) 'path_description': pathDescription,
    if (discipleLevel.isNotEmpty) 'disciple_level': discipleLevel,
    ...ref.toQuery(),
  };
  return Uri(path: AppRoutes.studyGuideV2, queryParameters: query).toString();
}
