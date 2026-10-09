import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

/// Keeps other screens' counters current once a lesson completion has been
/// recorded on the server.
///
/// Completing a topic changes the progress of whatever path it belongs to,
/// and both the learning path lists and the per-path detail are cached (the
/// persisted copy outlives the process), so the cache is dropped. The XP the
/// completion awarded also changes the totals [GamificationBloc] shows, which
/// otherwise kept the pre-lesson XP until the next full reload.
void refreshAfterLessonCompletion({
  required LearningPathsRepository learningPaths,
  required GamificationBloc gamification,
}) {
  learningPaths.clearCache();
  gamification.add(const RefreshGamificationStats());
}
