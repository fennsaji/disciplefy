import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_guide_entity.dart';

abstract class SavedGuidesEvent extends Equatable {
  const SavedGuidesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavedGuides extends SavedGuidesEvent {}

class LoadRecentGuides extends SavedGuidesEvent {}

class SaveGuideEvent extends SavedGuidesEvent {
  final SavedGuideEntity guide;

  const SaveGuideEvent(this.guide);

  @override
  List<Object?> get props => [guide];
}

class RemoveGuideEvent extends SavedGuidesEvent {
  final String guideId;

  const RemoveGuideEvent(this.guideId);

  @override
  List<Object?> get props => [guideId];
}

class AddToRecentEvent extends SavedGuidesEvent {
  final SavedGuideEntity guide;

  const AddToRecentEvent(this.guide);

  @override
  List<Object?> get props => [guide];
}

class ClearAllSavedEvent extends SavedGuidesEvent {}

class ClearAllRecentEvent extends SavedGuidesEvent {}

class WatchSavedGuidesEvent extends SavedGuidesEvent {}

class WatchRecentGuidesEvent extends SavedGuidesEvent {}