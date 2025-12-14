import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/purchase_issue_entity.dart';
import '../../domain/usecases/submit_purchase_issue_usecase.dart';
import 'purchase_issue_event.dart';
import 'purchase_issue_state.dart';

/// BLoC for managing purchase issue report state
class PurchaseIssueBloc extends Bloc<PurchaseIssueEvent, PurchaseIssueState> {
  final SubmitPurchaseIssueUseCase submitPurchaseIssueUseCase;
  final UploadIssueScreenshotUseCase uploadIssueScreenshotUseCase;

  PurchaseIssueBloc({
    required this.submitPurchaseIssueUseCase,
    required this.uploadIssueScreenshotUseCase,
  }) : super(const PurchaseIssueInitial()) {
    on<InitializePurchaseIssueForm>(_onInitializeForm);
    on<IssueTypeChanged>(_onIssueTypeChanged);
    on<DescriptionChanged>(_onDescriptionChanged);
    on<UploadScreenshotRequested>(_onUploadScreenshot);
    on<RemoveScreenshot>(_onRemoveScreenshot);
    on<SubmitPurchaseIssueRequested>(_onSubmitIssue);
    on<ResetPurchaseIssueState>(_onReset);
  }

  void _onInitializeForm(
    InitializePurchaseIssueForm event,
    Emitter<PurchaseIssueState> emit,
  ) {
    emit(PurchaseIssueFormReady(
      purchaseId: event.purchaseId,
      paymentId: event.paymentId,
      orderId: event.orderId,
      tokenAmount: event.tokenAmount,
      costRupees: event.costRupees,
      purchasedAt: event.purchasedAt,
    ));
  }

  void _onIssueTypeChanged(
    IssueTypeChanged event,
    Emitter<PurchaseIssueState> emit,
  ) {
    final currentState = state;
    if (currentState is PurchaseIssueFormReady) {
      emit(currentState.copyWith(issueType: event.issueType));
    }
  }

  void _onDescriptionChanged(
    DescriptionChanged event,
    Emitter<PurchaseIssueState> emit,
  ) {
    final currentState = state;
    if (currentState is PurchaseIssueFormReady) {
      emit(currentState.copyWith(description: event.description));
    }
  }

  Future<void> _onUploadScreenshot(
    UploadScreenshotRequested event,
    Emitter<PurchaseIssueState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseIssueFormReady) return;

    if (!currentState.canAddScreenshot) {
      emit(currentState.copyWith(
        uploadError: 'Maximum 3 screenshots allowed',
      ));
      return;
    }

    emit(currentState.copyWith(isUploadingScreenshot: true));

    final result = await uploadIssueScreenshotUseCase(
      UploadScreenshotParams(
        fileName: event.fileName,
        fileBytes: event.fileBytes,
        mimeType: event.mimeType,
      ),
    );

    result.fold(
      (failure) {
        emit(currentState.copyWith(
          isUploadingScreenshot: false,
          uploadError: failure.message,
        ));
      },
      (response) {
        if (response.success && response.url != null) {
          final newUrls = [...currentState.screenshotUrls, response.url!];
          emit(currentState.copyWith(
            isUploadingScreenshot: false,
            screenshotUrls: newUrls,
          ));
        } else {
          emit(currentState.copyWith(
            isUploadingScreenshot: false,
            uploadError: response.error ?? 'Failed to upload screenshot',
          ));
        }
      },
    );
  }

  void _onRemoveScreenshot(
    RemoveScreenshot event,
    Emitter<PurchaseIssueState> emit,
  ) {
    final currentState = state;
    if (currentState is PurchaseIssueFormReady) {
      final newUrls = List<String>.from(currentState.screenshotUrls);
      if (event.index >= 0 && event.index < newUrls.length) {
        newUrls.removeAt(event.index);
        emit(currentState.copyWith(screenshotUrls: newUrls));
      }
    }
  }

  Future<void> _onSubmitIssue(
    SubmitPurchaseIssueRequested event,
    Emitter<PurchaseIssueState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PurchaseIssueFormReady) return;

    if (!currentState.isValid) {
      emit(PurchaseIssueSubmitFailure(
        message: 'Please provide a description (10-2000 characters)',
        previousState: currentState,
      ));
      return;
    }

    emit(const PurchaseIssueSubmitting());

    final issue = PurchaseIssueEntity(
      purchaseId: currentState.purchaseId,
      paymentId: currentState.paymentId,
      orderId: currentState.orderId,
      tokenAmount: currentState.tokenAmount,
      costRupees: currentState.costRupees,
      purchasedAt: currentState.purchasedAt,
      issueType: currentState.issueType,
      description: currentState.description.trim(),
      screenshotUrls: currentState.screenshotUrls,
    );

    final result = await submitPurchaseIssueUseCase(
      SubmitPurchaseIssueParams(issue: issue),
    );

    result.fold(
      (failure) {
        emit(PurchaseIssueSubmitFailure(
          message: failure.message,
          previousState: currentState,
        ));
      },
      (response) {
        emit(PurchaseIssueSubmitSuccess(
          message: response.message,
          reportId: response.reportId,
        ));
      },
    );
  }

  void _onReset(
    ResetPurchaseIssueState event,
    Emitter<PurchaseIssueState> emit,
  ) {
    emit(const PurchaseIssueInitial());
  }
}
