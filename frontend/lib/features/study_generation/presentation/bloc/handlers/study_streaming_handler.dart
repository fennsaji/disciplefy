import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/error_message_sanitizer.dart';
import '../../../data/services/study_stream_service.dart';
import '../../../domain/entities/study_mode.dart';
import '../../../domain/entities/study_stream_event.dart';
import '../study_event.dart';
import '../study_state.dart';
import '../../../../../core/utils/logger.dart';

/// Handler for streaming study guide generation logic.
///
/// This class manages the SSE stream for progressive study guide rendering,
/// emitting sections as they arrive from the backend.
class StudyStreamingHandler {
  final StudyStreamService _streamService;

  /// Active stream subscription for cancellation
  StreamSubscription<StudyStreamEvent>? _activeSubscription;

  /// Flag to track if stream was cancelled
  bool _isCancelled = false;

  StudyStreamingHandler({
    required StudyStreamService streamService,
  }) : _streamService = streamService;

  /// Handles the streaming study guide generation request.
  ///
  /// This method initiates the SSE stream and dispatches internal events
  /// as sections arrive. The BLoC should handle these internal events to
  /// update the UI progressively.
  Future<void> handleGenerateStudyGuideStreaming(
    GenerateStudyGuideStreamingRequested event,
    Emitter<StudyState> emit,
    void Function(StudyEvent) add,
  ) async {
    Logger.debug('🌊 [STREAMING_HANDLER] Starting streaming generation');
    _isCancelled = false;

    // Emit initial streaming state
    emit(StudyGenerationStreaming(
      content: StreamingStudyGuideContent.empty(),
      inputType: event.inputType,
      inputValue: event.input,
      language: event.language,
    ));

    try {
      final stream = _streamService.streamStudyGuide(
        inputType: event.inputType,
        inputValue: event.input,
        topicDescription: event.topicDescription,
        language: event.language,
        studyMode: event.studyMode,
      );

      await for (final streamEvent in stream) {
        // Check for cancellation
        if (_isCancelled) {
          Logger.debug('🌊 [STREAMING_HANDLER] Stream cancelled by user');
          break;
        }

        // Handle each event type
        if (streamEvent is StudyStreamInitEvent) {
          Logger.debug('🌊 [STREAMING_HANDLER] Init: ${streamEvent.status}');
          // Init event received, stream is starting
          // The state is already set, nothing else to do here
        } else if (streamEvent is StudyStreamSectionEvent) {
          Logger.debug(
              '🌊 [STREAMING_HANDLER] Section: ${streamEvent.sectionType}');
          // Dispatch internal event to update state with new section
          add(StudyStreamSectionReceived(sectionEvent: streamEvent));
        } else if (streamEvent is StudyStreamCompleteEvent) {
          Logger.debug(
              '🌊 [STREAMING_HANDLER] Complete: ${streamEvent.studyGuideId}');
          // Dispatch completion event
          add(StudyStreamCompleted(
            studyGuideId: streamEvent.studyGuideId,
            tokensConsumed: streamEvent.tokensConsumed,
            fromCache: streamEvent.fromCache,
          ));
          break;
        } else if (streamEvent is StudyStreamErrorEvent) {
          Logger.debug(
              '🌊 [STREAMING_HANDLER] Error: ${streamEvent.code} - ${streamEvent.message}');
          // Dispatch error event
          add(StudyStreamErrorOccurred(
            code: streamEvent.code,
            message: streamEvent.message,
            retryable: streamEvent.retryable,
          ));
          break;
        }
      }
    } catch (e) {
      Logger.debug('🌊 [STREAMING_HANDLER] Exception: $e');
      if (!_isCancelled) {
        add(StudyStreamErrorOccurred(
          code: 'STREAM_EXCEPTION',
          message: 'An unexpected error occurred during streaming',
          retryable: true,
        ));
      }
    }
  }

  /// Handles receiving a streamed section.
  ///
  /// Updates the streaming state with the new section content.
  void handleStreamSectionReceived(
    StudyStreamSectionReceived event,
    Emitter<StudyState> emit,
    StudyState currentState,
  ) {
    if (currentState is! StudyGenerationStreaming) {
      Logger.debug(
          '🌊 [STREAMING_HANDLER] Section received but not in streaming state');
      return;
    }

    final sectionEvent = event.sectionEvent as StudyStreamSectionEvent;
    final updatedState = currentState.withSection(sectionEvent);

    emit(updatedState);
  }

  /// Handles stream completion.
  ///
  /// Transitions from streaming state to success state with the complete
  /// study guide data.
  void handleStreamCompleted(
    StudyStreamCompleted event,
    Emitter<StudyState> emit,
    StudyState currentState,
  ) {
    if (currentState is! StudyGenerationStreaming) {
      Logger.debug(
          '🌊 [STREAMING_HANDLER] Complete received but not in streaming state');
      return;
    }

    Logger.debug('🌊 [STREAMING_HANDLER] Stream completed successfully');
    Logger.debug(
        '🌊 [STREAMING_HANDLER] Study Guide ID: ${event.studyGuideId}');
    Logger.debug(
        '🌊 [STREAMING_HANDLER] Tokens consumed: ${event.tokensConsumed}');
    Logger.debug('🌊 [STREAMING_HANDLER] From cache: ${event.fromCache}');

    // Convert streaming content to a complete study guide
    // For now, we keep the streaming state but mark it as complete
    // The UI can detect isComplete and render accordingly
    final content = currentState.content;

    // Create a new streaming state with completion info.
    // Set sectionsLoaded = totalSections so isComplete flips to true.
    // The backend complete event is authoritative — trust it even if a section
    // was skipped (e.g. an optional passage section with no content).
    emit(StudyGenerationStreaming(
      content: content.copyWith(
        studyGuideId: event.studyGuideId,
        isFromCache: event.fromCache,
        sectionsLoaded:
            content.totalSections, // Mark complete: trust the backend
      ),
      inputType: currentState.inputType,
      inputValue: currentState.inputValue,
      language: currentState.language,
    ));
  }

  /// Handles stream errors.
  ///
  /// Transitions to failed state, preserving partial content if available.
  void handleStreamErrorOccurred(
    StudyStreamErrorOccurred event,
    Emitter<StudyState> emit,
    StudyState currentState,
  ) {
    Logger.debug('🌊 [STREAMING_HANDLER] Handling stream error: ${event.code}');

    StreamingStudyGuideContent? partialContent;
    String inputType = '';
    String inputValue = '';
    String language = '';

    if (currentState is StudyGenerationStreaming) {
      partialContent = currentState.content;
      inputType = currentState.inputType;
      inputValue = currentState.inputValue;
      language = currentState.language;
    }

    // Create failure from error event - preserve the failure type for proper UI handling
    final failure = _createFailureFromError(event.code, event.message);
    final sanitizedMessage = ErrorMessageSanitizer.sanitize(failure);

    // Create sanitized failure preserving the original type
    final sanitizedFailure = _createSanitizedFailure(
      failure,
      sanitizedMessage,
      event.code,
    );

    emit(StudyGenerationStreamingFailed(
      partialContent: partialContent,
      failure: sanitizedFailure,
      canRetry: event.retryable,
      inputType: inputType,
      inputValue: inputValue,
      language: language,
    ));
  }

  /// Handles stream cancellation request.
  ///
  /// Cancels the active stream and resets state.
  void handleCancelStreaming(
    CancelStudyStreamingRequested event,
    Emitter<StudyState> emit,
  ) {
    Logger.debug('🌊 [STREAMING_HANDLER] Cancelling stream');
    _isCancelled = true;
    _activeSubscription?.cancel();
    _activeSubscription = null;

    // Return to initial state
    emit(const StudyInitial());
  }

  /// Creates a sanitized Failure preserving the original type for proper UI handling.
  Failure _createSanitizedFailure(
    Failure original,
    String sanitizedMessage,
    String code,
  ) {
    // Preserve the failure type so UI can detect token errors properly
    if (original is TokenFailure) {
      return TokenFailure(message: sanitizedMessage, code: code);
    } else if (original is AuthenticationFailure) {
      return AuthenticationFailure(message: sanitizedMessage, code: code);
    } else if (original is RateLimitFailure) {
      return RateLimitFailure(message: sanitizedMessage, code: code);
    } else if (original is ValidationFailure) {
      return ValidationFailure(message: sanitizedMessage, code: code);
    } else if (original is NetworkFailure) {
      return NetworkFailure(message: sanitizedMessage, code: code);
    } else {
      return ServerFailure(message: sanitizedMessage, code: code);
    }
  }

  /// Creates a Failure object from error code and message.
  Failure _createFailureFromError(String code, String message) {
    // Map error codes to appropriate failure types
    if (code.startsWith('AUTH')) {
      return AuthenticationFailure(message: message, code: code);
    } else if (code.startsWith('RATE')) {
      return RateLimitFailure(message: message, code: code);
    } else if (code.startsWith('TOKEN') || code.startsWith('INSUFFICIENT')) {
      return TokenFailure(message: message, code: code);
    } else if (code.startsWith('VALIDATION')) {
      return ValidationFailure(message: message, code: code);
    } else if (code.startsWith('NETWORK') || code == 'STREAM_EXCEPTION') {
      return NetworkFailure(message: message, code: code);
    } else {
      return ServerFailure(message: message, code: code);
    }
  }

  /// Cleanup resources when handler is disposed.
  void dispose() {
    _isCancelled = true;
    _activeSubscription?.cancel();
    _activeSubscription = null;
    _streamService.closeAllConnections();
  }
}
