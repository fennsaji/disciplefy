import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../../study_generation/domain/usecases/generate_study_guide.dart';
import 'home_study_generation_event.dart';
import 'home_study_generation_state.dart';

/// BLoC for managing study guide generation from the Home screen.
/// 
/// This BLoC follows the Single Responsibility Principle by handling
/// only study guide generation from verses and topics.
class HomeStudyGenerationBloc extends Bloc<HomeStudyGenerationEvent, HomeStudyGenerationState> {
  final GenerateStudyGuide _generateStudyGuideUseCase;

  HomeStudyGenerationBloc({
    required GenerateStudyGuide generateStudyGuideUseCase,
  })  : _generateStudyGuideUseCase = generateStudyGuideUseCase,
        super(const HomeStudyGenerationInitial()) {
    
    on<GenerateStudyGuideFromVerse>(_onGenerateFromVerse);
    on<GenerateStudyGuideFromTopic>(_onGenerateFromTopic);
    on<ClearHomeStudyGenerationError>(_onClearError);
  }

  /// Handle generating study guide from verse
  Future<void> _onGenerateFromVerse(
    GenerateStudyGuideFromVerse event,
    Emitter<HomeStudyGenerationState> emit,
  ) async {
    await _generateStudyGuide(
      input: event.verseReference,
      inputType: 'scripture',
      language: event.language,
      emit: emit,
    );
  }

  /// Handle generating study guide from topic
  Future<void> _onGenerateFromTopic(
    GenerateStudyGuideFromTopic event,
    Emitter<HomeStudyGenerationState> emit,
  ) async {
    await _generateStudyGuide(
      input: event.topicName,
      inputType: 'topic',
      language: event.language,
      emit: emit,
    );
  }

  /// Common study guide generation logic
  Future<void> _generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
    required Emitter<HomeStudyGenerationState> emit,
  }) async {
    emit(HomeStudyGenerationInProgress(
      input: input,
      inputType: inputType,
    ));

    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        // Create study guide generation parameters
        final studyParams = StudyGenerationParams(
          input: input,
          inputType: inputType,
          language: language,
        );

        // Generate study guide
        final result = await _generateStudyGuideUseCase(studyParams);

        ErrorHandler.handleEitherResult(
          result: result,
          emit: emit,
          createErrorState: (message, errorCode) => HomeStudyGenerationError(
            message: message,
            input: input,
            inputType: inputType,
            errorCode: errorCode,
          ),
          onSuccess: (dynamic studyGuide) {
            Logger.info(
              'Study guide generated successfully from Home screen',
              tag: 'HOME_STUDY_GENERATION',
              context: {
                'input': input,
                'input_type': inputType,
                'language': language,
              },
            );
            
            emit(HomeStudyGenerationSuccess(studyGuide: studyGuide));
          },
          operationName: 'generate study guide from home',
        );
      },
      emit: emit,
      createErrorState: (message, errorCode) => HomeStudyGenerationError(
        message: message,
        input: input,
        inputType: inputType,
        errorCode: errorCode,
      ),
      operationName: 'home study guide generation',
    );
  }

  /// Handle clearing errors
  void _onClearError(
    ClearHomeStudyGenerationError event,
    Emitter<HomeStudyGenerationState> emit,
  ) {
    if (state is HomeStudyGenerationError) {
      emit(const HomeStudyGenerationInitial());
    }
  }
}