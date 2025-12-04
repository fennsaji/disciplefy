import 'package:equatable/equatable.dart';

abstract class SavedGuidesEvent extends Equatable {
  const SavedGuidesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavedGuides extends SavedGuidesEvent {}

class LoadRecentGuides extends SavedGuidesEvent {}

// API-related events
class LoadSavedGuidesFromApi extends SavedGuidesEvent {
  final int offset;
  final int limit;
  final bool refresh;

  const LoadSavedGuidesFromApi({
    this.offset = 0,
    this.limit = 20,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [offset, limit, refresh];
}

class LoadRecentGuidesFromApi extends SavedGuidesEvent {
  final int offset;
  final int limit;
  final bool refresh;

  const LoadRecentGuidesFromApi({
    this.offset = 0,
    this.limit = 20,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [offset, limit, refresh];
}

class ToggleGuideApiEvent extends SavedGuidesEvent {
  final String guideId;
  final bool save;

  const ToggleGuideApiEvent({
    required this.guideId,
    required this.save,
  });

  @override
  List<Object?> get props => [guideId, save];
}

class TabChangedEvent extends SavedGuidesEvent {
  final int tabIndex;

  const TabChangedEvent({required this.tabIndex});

  @override
  List<Object?> get props => [tabIndex];
}
