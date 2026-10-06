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
  final ref = LessonRef(
    pathId: path.id,
    pathTitle: path.title,
    lessonNumber: index < 0 ? 1 : index + 1,
    lessonTotal: ordered.length,
  );
  final query = <String, String>{
    'input': topic.title,
    'type': topic.inputType,
    'language': language,
    'mode': mode.name,
    'source': source,
    if (topic.topicId.isNotEmpty) 'topic_id': topic.topicId,
    if (topic.description.isNotEmpty) 'description': topic.description,
    if (path.description.isNotEmpty) 'path_description': path.description,
    if (path.discipleLevel.isNotEmpty) 'disciple_level': path.discipleLevel,
    ...ref.toQuery(),
  };
  return Uri(path: AppRoutes.studyGuideV2, queryParameters: query).toString();
}
