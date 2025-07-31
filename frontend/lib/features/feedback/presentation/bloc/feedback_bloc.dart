import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/submit_feedback_usecase.dart';
import 'feedback_event.dart';
import 'feedback_state.dart';

/// BLoC for managing feedback submission state
class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final SubmitFeedbackUseCase submitFeedbackUseCase;

  FeedbackBloc({
    required this.submitFeedbackUseCase,
  }) : super(const FeedbackInitial()) {
    on<SubmitFeedbackRequested>(_onSubmitFeedbackRequested);
    on<SubmitGeneralFeedbackRequested>(_onSubmitGeneralFeedbackRequested);
    on<SubmitBugReportRequested>(_onSubmitBugReportRequested);
    on<ResetFeedbackState>(_onResetFeedbackState);
  }

  Future<void> _onSubmitFeedbackRequested(
    SubmitFeedbackRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackSubmitting());

    final result = await submitFeedbackUseCase(
      SubmitFeedbackParams(feedback: event.feedback),
    );

    result.fold(
      (failure) => emit(FeedbackSubmitFailure(message: failure.message)),
      (_) => emit(const FeedbackSubmitSuccess()),
    );
  }

  Future<void> _onSubmitGeneralFeedbackRequested(
    SubmitGeneralFeedbackRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackSubmitting());

    final params = SubmitFeedbackParams.general(
      wasHelpful: event.wasHelpful,
      message: event.message,
      category: event.category,
      userContext: event.userContext,
    );

    final result = await submitFeedbackUseCase(params);

    result.fold(
      (failure) => emit(FeedbackSubmitFailure(message: failure.message)),
      (_) => emit(const FeedbackSubmitSuccess()),
    );
  }

  Future<void> _onSubmitBugReportRequested(
    SubmitBugReportRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackSubmitting());

    final params = SubmitFeedbackParams.bugReport(
      message: event.message,
      userContext: event.userContext,
    );

    final result = await submitFeedbackUseCase(params);

    result.fold(
      (failure) => emit(FeedbackSubmitFailure(message: failure.message)),
      (_) => emit(const FeedbackSubmitSuccess(
        message: 'Bug report submitted successfully. Thank you for helping us improve!',
      )),
    );
  }

  void _onResetFeedbackState(
    ResetFeedbackState event,
    Emitter<FeedbackState> emit,
  ) {
    emit(const FeedbackInitial());
  }
}