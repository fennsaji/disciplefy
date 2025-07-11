import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/constants/app_constants.dart';
import '../entities/study_guide.dart';
import '../repositories/study_repository.dart';

/// Parameters for study guide generation.
/// 
/// This class encapsulates all the information needed to generate
/// a study guide, including validation rules.
class StudyGenerationParams extends Equatable {
  /// The input text (verse reference or topic).
  final String input;
  
  /// The type of input ('scripture' or 'topic').
  final String inputType;
  
  /// Optional language code for the study guide.
  final String? language;

  const StudyGenerationParams({
    required this.input,
    required this.inputType,
    this.language,
  });

  @override
  List<Object?> get props => [input, inputType, language];

  /// Validates the parameters.
  /// 
  /// Returns a [ValidationFailure] if the parameters are invalid,
  /// otherwise returns null.
  ValidationFailure? validate() {
    if (input.trim().isEmpty) {
      return const ValidationFailure(
        message: 'Input cannot be empty',
        code: 'EMPTY_INPUT',
      );
    }

    if (input.trim().length < AppConstants.MIN_INPUT_LENGTH) {
      return const ValidationFailure(
        message: 'Input must be at least ${AppConstants.MIN_INPUT_LENGTH} characters',
        code: 'INPUT_TOO_SHORT',
      );
    }

    if (inputType == 'scripture' && input.length > AppConstants.MAX_VERSE_LENGTH) {
      return const ValidationFailure(
        message: 'Verse reference cannot exceed ${AppConstants.MAX_VERSE_LENGTH} characters',
        code: 'VERSE_TOO_LONG',
      );
    }

    if (inputType == 'topic' && input.length > AppConstants.MAX_TOPIC_LENGTH) {
      return const ValidationFailure(
        message: 'Topic cannot exceed ${AppConstants.MAX_TOPIC_LENGTH} characters',
        code: 'TOPIC_TOO_LONG',
      );
    }

    if (inputType != 'scripture' && inputType != 'topic') {
      return const ValidationFailure(
        message: 'Input type must be either "scripture" or "topic"',
        code: 'INVALID_INPUT_TYPE',
      );
    }

    return null;
  }
}

/// Use case for generating Bible study guides.
/// 
/// This use case implements the business logic for generating study guides
/// from verse references or topics, following Clean Architecture principles.
class GenerateStudyGuide {
  /// Repository for study guide operations.
  final StudyRepository _repository;

  /// Creates a new GenerateStudyGuide use case.
  /// 
  /// [repository] The repository to use for study guide operations.
  const GenerateStudyGuide(this._repository);

  /// Generates a study guide based on the provided parameters.
  /// 
  /// This method validates the input, calls the repository, and returns
  /// either a [StudyGuide] on success or a [Failure] on error.
  /// 
  /// [params] The parameters for study guide generation.
  /// 
  /// Returns an [Either] containing either a [Failure] or [StudyGuide].
  Future<Either<Failure, StudyGuide>> call(StudyGenerationParams params) async {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      return Left(validationError);
    }

    try {
      // Call repository to generate study guide
      return await _repository.generateStudyGuide(
        input: params.input.trim(),
        inputType: params.inputType,
        language: params.language ?? AppConstants.DEFAULT_LANGUAGE,
      );
    } catch (e) {
      // Handle unexpected exceptions
      return Left(ClientFailure(
        message: 'Failed to generate study guide',
        code: 'GENERATION_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}