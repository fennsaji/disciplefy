import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Debug helper for BLoC emit operations
///
/// This utility helps debug emit issues in BLoC by providing
/// safe emit methods with logging and validation.
class BlocDebugHelper {
  /// Safely emits a state with logging and validation
  ///
  /// [emitter] The BLoC emitter instance
  /// [state] The state to emit
  /// [eventName] Optional event name for logging
  /// [blocName] Optional bloc name for logging
  static void safeEmit<T>(
    Emitter<T> emitter,
    T state, {
    String? eventName,
    String? blocName,
  }) {
    if (emitter.isDone) {
      if (kDebugMode) {
        print('[BLoC Debug] ${blocName ?? 'Unknown'}: '
            'Attempted to emit ${state.runtimeType} after emitter completed '
            '${eventName != null ? 'in event $eventName' : ''}');
      }
      return;
    }

    if (kDebugMode) {
      print('[BLoC Debug] ${blocName ?? 'Unknown'}: '
          'Emitting ${state.runtimeType} '
          '${eventName != null ? 'from event $eventName' : ''}');
    }

    emitter(state);
  }

  /// Safely emits a state after an async operation
  ///
  /// [emitter] The BLoC emitter instance
  /// [state] The state to emit
  /// [eventName] Optional event name for logging
  /// [blocName] Optional bloc name for logging
  static Future<void> safeEmitAsync<T>(
    Emitter<T> emitter,
    T state, {
    String? eventName,
    String? blocName,
  }) async {
    // Add a small delay to ensure async operations complete
    await Future.microtask(() {});

    safeEmit(emitter, state, eventName: eventName, blocName: blocName);
  }

  /// Logs BLoC event handling start
  ///
  /// [eventName] The name of the event being handled
  /// [blocName] The name of the bloc
  static void logEventStart(String eventName, String blocName) {
    if (kDebugMode) {
      print('[BLoC Debug] $blocName: Started handling event $eventName');
    }
  }

  /// Logs BLoC event handling completion
  ///
  /// [eventName] The name of the event that was handled
  /// [blocName] The name of the bloc
  /// [duration] Optional duration of the event handling
  static void logEventEnd(
    String eventName,
    String blocName, {
    Duration? duration,
  }) {
    if (kDebugMode) {
      final durationText =
          duration != null ? ' (${duration.inMilliseconds}ms)' : '';
      print(
          '[BLoC Debug] $blocName: Finished handling event $eventName$durationText');
    }
  }

  /// Logs an error in BLoC event handling
  ///
  /// [eventName] The name of the event that caused the error
  /// [blocName] The name of the bloc
  /// [error] The error that occurred
  /// [stackTrace] Optional stack trace
  static void logEventError(
    String eventName,
    String blocName,
    Object error, {
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      print('[BLoC Debug] $blocName: Error in event $eventName: $error');
      if (stackTrace != null) {
        print('[BLoC Debug] Stack trace: $stackTrace');
      }
    }
  }

  /// Validates that an emitter is still valid before use
  ///
  /// [emitter] The BLoC emitter instance
  /// [eventName] Optional event name for logging
  /// [blocName] Optional bloc name for logging
  ///
  /// Returns true if the emitter is valid, false otherwise
  static bool validateEmitter<T>(
    Emitter<T> emitter, {
    String? eventName,
    String? blocName,
  }) {
    if (emitter.isDone) {
      if (kDebugMode) {
        print('[BLoC Debug] ${blocName ?? 'Unknown'}: '
            'Emitter is done, cannot emit '
            '${eventName != null ? 'in event $eventName' : ''}');
      }
      return false;
    }
    return true;
  }
}

/// Extension methods for easier BLoC debugging
extension BlocEmitterDebugExtension<T> on Emitter<T> {
  /// Safely emits a state with automatic logging
  void safeEmit(
    T state, {
    String? eventName,
    String? blocName,
  }) {
    BlocDebugHelper.safeEmit(this, state,
        eventName: eventName, blocName: blocName);
  }

  /// Safely emits a state after an async operation
  Future<void> safeEmitAsync(
    T state, {
    String? eventName,
    String? blocName,
  }) =>
      BlocDebugHelper.safeEmitAsync(this, state,
          eventName: eventName, blocName: blocName);

  /// Validates that this emitter is still valid
  bool isValid({String? eventName, String? blocName}) =>
      BlocDebugHelper.validateEmitter(this,
          eventName: eventName, blocName: blocName);
}

/// Example usage:
///
/// ```dart
/// Future<void> _onSomeEvent(
///   SomeEvent event,
///   Emitter<SomeState> emit,
/// ) async {
///   BlocDebugHelper.logEventStart('SomeEvent', 'SomeBloc');
///   final stopwatch = Stopwatch()..start();
///
///   try {
///     emit.safeEmit(
///       SomeLoadingState(),
///       eventName: 'SomeEvent',
///       blocName: 'SomeBloc',
///     );
///
///     final result = await someAsyncOperation();
///
///     emit.safeEmit(
///       SomeSuccessState(result),
///       eventName: 'SomeEvent',
///       blocName: 'SomeBloc',
///     );
///   } catch (error, stackTrace) {
///     BlocDebugHelper.logEventError('SomeEvent', 'SomeBloc', error, stackTrace: stackTrace);
///
///     emit.safeEmit(
///       SomeErrorState(error.toString()),
///       eventName: 'SomeEvent',
///       blocName: 'SomeBloc',
///     );
///   } finally {
///     stopwatch.stop();
///     BlocDebugHelper.logEventEnd('SomeEvent', 'SomeBloc', duration: stopwatch.elapsed);
///   }
/// }
/// ```
