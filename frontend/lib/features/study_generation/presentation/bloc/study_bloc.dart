import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/usecases/generate_study_guide.dart';

/// Events for the Study Generation BLoC.
/// 
/// These events represent user actions that trigger study guide generation
/// or related operations.
abstract class StudyEvent extends Equatable {
  const StudyEvent();

  @override
  List<Object> get props => [];
}

/// Event to request generation of a new study guide.
/// 
/// This event is triggered when a user submits a verse or topic
/// for study guide generation.
class GenerateStudyGuideRequested extends StudyEvent {
  /// The input text (verse reference or topic).
  final String input;
  
  /// The type of input ('scripture' or 'topic').
  final String inputType;
  
  /// Optional language code for the study guide.
  final String? language;

  const GenerateStudyGuideRequested({
    required this.input,
    required this.inputType,
    this.language,
  });

  @override
  List<Object> get props => [input, inputType, language ?? ''];
}

/// Event to clear the current study guide state.
class StudyGuideCleared extends StudyEvent {
  const StudyGuideCleared();
}

/// States for the Study Generation BLoC.
/// 
/// These states represent the current status of study guide generation
/// and related operations.
abstract class StudyState extends Equatable {
  const StudyState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no study generation has been attempted.
class StudyInitial extends StudyState {
  const StudyInitial();
}

/// State indicating that study guide generation is in progress.
class StudyGenerationInProgress extends StudyState {
  /// Optional progress indicator (0.0 to 1.0).
  final double? progress;

  const StudyGenerationInProgress({this.progress});

  @override
  List<Object?> get props => [progress];
}

/// State indicating successful study guide generation.
class StudyGenerationSuccess extends StudyState {
  /// The generated study guide.
  final StudyGuide studyGuide;
  
  /// Timestamp of generation for caching purposes.
  final DateTime generatedAt;

  const StudyGenerationSuccess({
    required this.studyGuide,
    required this.generatedAt,
  });

  @override
  List<Object> get props => [studyGuide, generatedAt];
}

/// State indicating that study guide generation failed.
class StudyGenerationFailure extends StudyState {
  /// The failure that occurred.
  final Failure failure;
  
  /// Whether the failure is retryable.
  final bool isRetryable;

  const StudyGenerationFailure({
    required this.failure,
    this.isRetryable = true,
  });

  @override
  List<Object> get props => [failure, isRetryable];
}

/// BLoC for managing study guide generation.
/// 
/// This BLoC handles the business logic for generating study guides
/// from verses or topics, including error handling and state management.
class StudyBloc extends Bloc<StudyEvent, StudyState> {
  /// Use case for generating study guides.
  final GenerateStudyGuide _generateStudyGuide;

  /// Creates a new StudyBloc instance.
  /// 
  /// [generateStudyGuide] is the use case responsible for study generation.
  StudyBloc({
    required GenerateStudyGuide generateStudyGuide,
  })  : _generateStudyGuide = generateStudyGuide,
        super(const StudyInitial()) {
    on<GenerateStudyGuideRequested>(_onGenerateStudyGuideRequested);
    on<StudyGuideCleared>(_onStudyGuideCleared);
  }

  /// Handles the study guide generation request event.
  /// 
  /// This method validates the input, calls the use case, and emits
  /// appropriate states based on the result.
  Future<void> _onGenerateStudyGuideRequested(
    GenerateStudyGuideRequested event,
    Emitter<StudyState> emit,
  ) async {
    emit(const StudyGenerationInProgress());

    try {
      final result = await _generateStudyGuide(
        StudyGenerationParams(
          input: event.input,
          inputType: event.inputType,
          language: event.language,
        ),
      );

      result.fold(
        (failure) => emit(StudyGenerationFailure(
          failure: failure,
          isRetryable: _isRetryableFailure(failure),
        )),
        (studyGuide) => emit(StudyGenerationSuccess(
          studyGuide: studyGuide,
          generatedAt: DateTime.now(),
        )),
      );
    } catch (e) {
      emit(StudyGenerationFailure(
        failure: ClientFailure(
          message: 'An unexpected error occurred during study generation',
          code: 'UNEXPECTED_ERROR',
          context: {'error': e.toString()},
        ),
        isRetryable: true,
      ));
    }
  }

  /// Handles the study guide cleared event.
  /// 
  /// This method resets the BLoC state to initial.
  void _onStudyGuideCleared(
    StudyGuideCleared event,
    Emitter<StudyState> emit,
  ) {
    emit(const StudyInitial());
  }

  /// Determines if a failure is retryable.
  /// 
  /// [failure] The failure to check.
  /// Returns true if the user should be allowed to retry the operation.
  bool _isRetryableFailure(Failure failure) {
    switch (failure.runtimeType) {
      case NetworkFailure:
      case ServerFailure:
      case RateLimitFailure:
        return true;
      case ValidationFailure:
      case AuthenticationFailure:
      case AuthorizationFailure:
        return false;
      default:
        return true;
    }
  }
}