import 'package:flutter_bloc/flutter_bloc.dart';

import '../error/failures.dart';
import 'logger.dart';

/// Shared error handling utility for BLoC error management
/// Reduces code duplication across modules and provides consistent error handling
class ErrorHandler {
  /// Generic error handler for BLoC operations
  /// 
  /// Features:
  /// - Consistent error message formatting
  /// - Debug mode logging
  /// - Type-safe error state emission
  /// - Customizable error codes and messages
  static void handleError<T extends Object>({
    required dynamic error,
    required Emitter<T> emit,
    required T Function(String message, String? errorCode) createErrorState,
    String? operationName,
    String? customMessage,
    String? errorCode,
  }) {
    String errorMessage;
    String? finalErrorCode;

    if (error is Failure) {
      // Handle domain failures
      errorMessage = customMessage ?? error.message;
      finalErrorCode = errorCode ?? error.code;
    } else if (error is Exception) {
      // Handle general exceptions
      errorMessage = customMessage ?? _extractErrorMessage(error, operationName);
      finalErrorCode = errorCode ?? _getErrorCodeFromException(error);
    } else {
      // Handle unknown errors
      errorMessage = customMessage ?? 'An unexpected error occurred';
      if (operationName != null) {
        errorMessage += ' during $operationName';
      }
      finalErrorCode = errorCode ?? 'UNKNOWN_ERROR';
    }

    // Structured logging
    final operation = operationName ?? 'operation';
    Logger.error(
      '$operation failed',
      tag: 'ERROR_HANDLER',
      context: {
        'operation': operation,
        'error_message': errorMessage,
        'error_code': finalErrorCode,
      },
      error: error,
    );

    // Emit error state
    emit(createErrorState(errorMessage, finalErrorCode));
  }

  /// Handles Either result pattern with error emission
  /// Common pattern for UseCase results
  static void handleEitherResult<TSuccess, TError extends Object, TFailure extends Failure>({
    required dynamic result,
    required Emitter<TError> emit,
    required TError Function(String message, String? errorCode) createErrorState,
    required void Function(TSuccess) onSuccess,
    String? operationName,
  }) {
    result.fold(
      (failure) => handleError(
        error: failure,
        emit: emit,
        createErrorState: createErrorState,
        operationName: operationName,
      ),
      onSuccess,
    );
  }

  /// Wraps an async operation with try-catch error handling
  /// Provides consistent error handling for async operations
  static Future<void> wrapAsyncOperation<T extends Object>({
    required Future<void> Function() operation,
    required Emitter<T> emit,
    required T Function(String message, String? errorCode) createErrorState,
    String? operationName,
    String? customErrorMessage,
  }) async {
    try {
      await operation();
    } catch (error) {
      handleError(
        error: error,
        emit: emit,
        createErrorState: createErrorState,
        operationName: operationName,
        customMessage: customErrorMessage,
      );
    }
  }

  /// Extracts meaningful error message from different exception types
  static String _extractErrorMessage(dynamic error, String? operationName) {
    final errorString = error.toString();
    
    // Common error patterns
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('internet')) {
      return 'Network error. Please check your connection and try again.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    if (errorString.contains('permission') || 
        errorString.contains('denied') ||
        errorString.contains('unauthorized')) {
      return 'Access denied. Please check your permissions.';
    }
    
    if (errorString.contains('not found') || 
        errorString.contains('404')) {
      return 'Resource not found.';
    }
    
    if (errorString.contains('server') || 
        errorString.contains('500') ||
        errorString.contains('503')) {
      return 'Server error. Please try again later.';
    }

    // Generic message with operation context
    if (operationName != null) {
      return 'Failed to $operationName. Please try again.';
    }
    
    return 'An error occurred. Please try again.';
  }

  /// Extracts error code from exception type
  static String _getErrorCodeFromException(dynamic error) {
    final errorType = error.runtimeType.toString().toLowerCase();
    
    if (errorType.contains('network')) return 'NETWORK_ERROR';
    if (errorType.contains('timeout')) return 'TIMEOUT_ERROR';
    if (errorType.contains('format')) return 'FORMAT_ERROR';
    if (errorType.contains('permission')) return 'PERMISSION_ERROR';
    if (errorType.contains('auth')) return 'AUTH_ERROR';
    if (errorType.contains('storage')) return 'STORAGE_ERROR';
    
    return 'GENERAL_ERROR';
  }
}

/// Extension methods for BLoC error handling
/// Provides consistent error handling without mixin complications
extension BlocErrorHandling<T extends Object> on Bloc<dynamic, T> {
  /// Handle error with automatic emit and emitter
  void handleBlocError({
    required dynamic error,
    required Emitter<T> emit,
    required T Function(String message, String? errorCode) createErrorState,
    String? operationName,
    String? customMessage,
    String? errorCode,
  }) {
    ErrorHandler.handleError(
      error: error,
      emit: emit,
      createErrorState: createErrorState,
      operationName: operationName,
      customMessage: customMessage,
      errorCode: errorCode,
    );
  }

  /// Wrap async operation with error handling and emitter
  Future<void> wrapBlocOperation({
    required Future<void> Function() operation,
    required Emitter<T> emit,
    required T Function(String message, String? errorCode) createErrorState,
    String? operationName,
    String? customErrorMessage,
  }) async {
    await ErrorHandler.wrapAsyncOperation(
      operation: operation,
      emit: emit,
      createErrorState: createErrorState,
      operationName: operationName,
      customErrorMessage: customErrorMessage,
    );
  }
}