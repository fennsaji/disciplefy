import 'package:equatable/equatable.dart';

import '../../../study_generation/domain/entities/study_guide.dart';

/// States for the Home Study Generation BLoC.
abstract class HomeStudyGenerationState extends Equatable {
  const HomeStudyGenerationState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no study guide generation has been attempted.
class HomeStudyGenerationInitial extends HomeStudyGenerationState {
  const HomeStudyGenerationInitial();
}

/// State when study guide generation is in progress.
class HomeStudyGenerationInProgress extends HomeStudyGenerationState {
  /// The input being used for generation.
  final String input;
  
  /// The type of input ('scripture' or 'topic').
  final String inputType;

  const HomeStudyGenerationInProgress({
    required this.input,
    required this.inputType,
  });

  @override
  List<Object?> get props => [input, inputType];
}

/// State when study guide generation completed successfully.
class HomeStudyGenerationSuccess extends HomeStudyGenerationState {
  /// The generated study guide.
  final StudyGuide studyGuide;

  const HomeStudyGenerationSuccess({
    required this.studyGuide,
  });

  @override
  List<Object?> get props => [studyGuide];
}

/// State when study guide generation failed.
class HomeStudyGenerationError extends HomeStudyGenerationState {
  /// The error message.
  final String message;
  
  /// The input that failed to generate.
  final String input;
  
  /// The type of input that failed.
  final String inputType;
  
  /// Optional error code for specific error handling.
  final String? errorCode;

  const HomeStudyGenerationError({
    required this.message,
    required this.input,
    required this.inputType,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, input, inputType, errorCode];
}