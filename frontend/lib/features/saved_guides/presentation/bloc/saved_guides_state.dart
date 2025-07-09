import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_guide_entity.dart';

abstract class SavedGuidesState extends Equatable {
  const SavedGuidesState();

  @override
  List<Object?> get props => [];
}

class SavedGuidesInitial extends SavedGuidesState {}

class SavedGuidesLoading extends SavedGuidesState {}

class SavedGuidesLoaded extends SavedGuidesState {
  final List<SavedGuideEntity> savedGuides;
  final List<SavedGuideEntity> recentGuides;

  const SavedGuidesLoaded({
    required this.savedGuides,
    required this.recentGuides,
  });

  @override
  List<Object?> get props => [savedGuides, recentGuides];

  SavedGuidesLoaded copyWith({
    List<SavedGuideEntity>? savedGuides,
    List<SavedGuideEntity>? recentGuides,
  }) {
    return SavedGuidesLoaded(
      savedGuides: savedGuides ?? this.savedGuides,
      recentGuides: recentGuides ?? this.recentGuides,
    );
  }
}

class SavedGuidesError extends SavedGuidesState {
  final String message;

  const SavedGuidesError({required this.message});

  @override
  List<Object?> get props => [message];
}

class SavedGuidesActionSuccess extends SavedGuidesState {
  final String message;

  const SavedGuidesActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}