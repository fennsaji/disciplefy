import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/generate_study_guide.dart';
import '../../domain/usecases/manage_personal_notes.dart';
import '../../domain/services/input_validation_service.dart';
import '../../data/services/save_guide_api_service.dart';
import '../../../auth/data/services/auth_service.dart';
import 'study_event.dart';
import 'study_state.dart';
import 'handlers/study_generation_handler.dart';
import 'handlers/study_save_handler.dart';
import 'handlers/study_validation_handler.dart';

/// BLoC for managing study guide generation and saving.
///
/// This refactored BLoC delegates specific responsibilities to handler classes,
/// following the Single Responsibility Principle and making the code more maintainable.
class StudyBloc extends Bloc<StudyEvent, StudyState> {
  // Handler instances for different concerns
  late final StudyGenerationHandler _generationHandler;
  late final StudySaveHandler _saveHandler;
  late final StudyValidationHandler _validationHandler;

  /// Creates a new StudyBloc instance.
  ///
  /// [generateStudyGuide] is the use case responsible for study generation.
  /// [saveGuideService] is the service responsible for save operations.
  /// [managePersonalNotes] is the use case responsible for personal notes operations.
  /// [validationService] is the service responsible for input validation.
  /// [authService] is the service responsible for authentication checks.
  StudyBloc({
    required GenerateStudyGuide generateStudyGuide,
    required SaveGuideApiService saveGuideService,
    required ManagePersonalNotesUseCase managePersonalNotes,
    required InputValidationService validationService,
    required AuthService authService,
  }) : super(const StudyInitial()) {
    // Initialize handlers with their dependencies
    _generationHandler = StudyGenerationHandler(
      generateStudyGuide: generateStudyGuide,
    );
    _saveHandler = StudySaveHandler(
      saveGuideService: saveGuideService,
      managePersonalNotes: managePersonalNotes,
      authService: authService,
    );
    _validationHandler = StudyValidationHandler(
      validationService: validationService,
    );

    // Register event handlers
    on<GenerateStudyGuideRequested>(
        _generationHandler.handleGenerateStudyGuide);
    on<StudyGuideCleared>(_generationHandler.handleClearStudyGuide);
    on<SaveStudyGuideRequested>(_saveHandler.handleSaveStudyGuide);
    on<ValidateInputRequested>(_validationHandler.handleValidateInput);
    on<CheckAuthenticationRequested>((event, emit) =>
        _saveHandler.handleCheckAuthentication(event, emit, add));

    // Register enhanced save event handlers
    on<EnhancedSaveStudyGuideRequested>(
        _saveHandler.handleEnhancedSaveStudyGuide);
    on<CheckEnhancedAuthenticationRequested>((event, emit) =>
        _saveHandler.handleCheckEnhancedAuthentication(event, emit, add));

    // Register personal notes event handlers
    on<UpdatePersonalNotesRequested>(_saveHandler.handleUpdatePersonalNotes);
    on<LoadPersonalNotesRequested>(_saveHandler.handleLoadPersonalNotes);
  }
}
