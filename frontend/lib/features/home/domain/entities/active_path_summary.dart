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
  });

  String get displayTitle =>
      (shortTitle?.isNotEmpty ?? false) ? shortTitle! : title;

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
      ];
}
