import 'package:equatable/equatable.dart';

import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/usecases/save_reflection.dart';
import '../../domain/usecases/list_reflections.dart';

/// Base class for all reflection-related events.
abstract class ReflectionsEvent extends Equatable {
  const ReflectionsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to save a reflection session.
class SaveReflectionRequested extends ReflectionsEvent {
  final SaveReflectionParams params;

  const SaveReflectionRequested(this.params);

  @override
  List<Object?> get props => [params];
}

/// Event to get a reflection by ID.
class GetReflectionRequested extends ReflectionsEvent {
  final String reflectionId;

  const GetReflectionRequested(this.reflectionId);

  @override
  List<Object?> get props => [reflectionId];
}

/// Event to get a reflection for a specific study guide.
class GetReflectionForGuideRequested extends ReflectionsEvent {
  final String studyGuideId;

  const GetReflectionForGuideRequested(this.studyGuideId);

  @override
  List<Object?> get props => [studyGuideId];
}

/// Event to list reflections with pagination.
class ListReflectionsRequested extends ReflectionsEvent {
  final ListReflectionsParams params;

  const ListReflectionsRequested(this.params);

  @override
  List<Object?> get props => [params];
}

/// Event to delete a reflection.
class DeleteReflectionRequested extends ReflectionsEvent {
  final String reflectionId;

  const DeleteReflectionRequested(this.reflectionId);

  @override
  List<Object?> get props => [reflectionId];
}

/// Event to get reflection statistics.
class GetReflectionStatsRequested extends ReflectionsEvent {
  const GetReflectionStatsRequested();
}
