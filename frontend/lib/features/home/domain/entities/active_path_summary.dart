import 'package:equatable/equatable.dart';

/// The next lesson a user should take in their active learning path.
class NextLesson extends Equatable {
  final String topicId;
  final String title;
  final String description;
  final String inputType;

  /// 1-based position of the lesson in the path.
  final int number;
  final int total;

  const NextLesson({
    required this.topicId,
    required this.title,
    required this.description,
    required this.inputType,
    required this.number,
    required this.total,
  });

  @override
  List<Object?> get props =>
      [topicId, title, description, inputType, number, total];
}

/// Home-screen summary of the user's active (or recommended) learning path.
class ActivePathSummary extends Equatable {
  final String pathId;
  final String title;
  final String? shortTitle;
  final String description;
  final String discipleLevel;
  final int lessonTotal;
  final int lessonsCompleted;

  /// Null when every lesson is complete (or the backend sent none).
  final NextLesson? next;

  /// 1-based lesson numbers that are milestones.
  final List<int> milestoneNumbers;
  final String? recommendedMode;

  /// 1-based number of the first unfinished lesson from the server's lesson
  /// rows; null when finished. Only meaningful when [nextLessonNumberKnown].
  final int? nextLessonNumber;

  /// Whether the server sent [nextLessonNumber] (older servers do not).
  final bool nextLessonNumberKnown;

  const ActivePathSummary({
    required this.pathId,
    required this.title,
    required this.description,
    required this.discipleLevel,
    required this.lessonTotal,
    required this.lessonsCompleted,
    this.shortTitle,
    this.next,
    this.milestoneNumbers = const [],
    this.recommendedMode,
    this.nextLessonNumber,
    this.nextLessonNumberKnown = false,
  });

  String get displayTitle =>
      (shortTitle?.isNotEmpty ?? false) ? shortTitle! : title;

  /// The lesson to highlight: [next]'s number, else the server's next lesson
  /// number (the last lesson once finished), else the old count-based guess.
  int get currentLessonNumber {
    if (next != null) return next!.number;
    if (nextLessonNumberKnown) {
      return nextLessonNumber ?? lessonTotal;
    }
    return isFinished ? lessonTotal : lessonsCompleted + 1;
  }

  bool get isFinished =>
      next == null && lessonsCompleted >= lessonTotal && lessonTotal > 0;

  @override
  List<Object?> get props => [
        pathId,
        title,
        shortTitle,
        description,
        discipleLevel,
        lessonTotal,
        lessonsCompleted,
        next,
        milestoneNumbers,
        recommendedMode,
        nextLessonNumber,
        nextLessonNumberKnown,
      ];
}
