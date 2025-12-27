import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/repositories/reflections_repository.dart';

/// Base class for all reflection-related states.
abstract class ReflectionsState extends Equatable {
  const ReflectionsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any operations.
class ReflectionsInitial extends ReflectionsState {
  const ReflectionsInitial();
}

/// Loading state during operations.
class ReflectionsLoading extends ReflectionsState {
  const ReflectionsLoading();
}

/// State when a reflection has been saved successfully.
class ReflectionSaved extends ReflectionsState {
  final ReflectionSession session;

  const ReflectionSaved(this.session);

  @override
  List<Object?> get props => [session];
}

/// State when a reflection has been loaded.
class ReflectionLoaded extends ReflectionsState {
  final ReflectionSession? session;

  const ReflectionLoaded(this.session);

  @override
  List<Object?> get props => [session];
}

/// State when reflections list has been loaded.
class ReflectionsListLoaded extends ReflectionsState {
  final ReflectionListResult result;

  const ReflectionsListLoaded(this.result);

  @override
  List<Object?> get props => [result];
}

/// State when reflection stats have been loaded.
class ReflectionStatsLoaded extends ReflectionsState {
  final ReflectionStats stats;

  const ReflectionStatsLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

/// State when a reflection has been deleted.
class ReflectionDeleted extends ReflectionsState {
  const ReflectionDeleted();
}

/// State when an error has occurred.
class ReflectionsError extends ReflectionsState {
  final Failure failure;

  const ReflectionsError(this.failure);

  @override
  List<Object?> get props => [failure];
}
