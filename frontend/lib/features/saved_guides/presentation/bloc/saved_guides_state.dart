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

// Enhanced states for API integration
class SavedGuidesApiLoaded extends SavedGuidesState {
  final List<SavedGuideEntity> savedGuides;
  final List<SavedGuideEntity> recentGuides;
  final bool isLoadingSaved;
  final bool isLoadingRecent;
  final bool hasMoreSaved;
  final bool hasMoreRecent;
  final int currentTab;

  const SavedGuidesApiLoaded({
    required this.savedGuides,
    required this.recentGuides,
    this.isLoadingSaved = false,
    this.isLoadingRecent = false,
    this.hasMoreSaved = true,
    this.hasMoreRecent = true,
    this.currentTab = 0,
  });

  @override
  List<Object?> get props => [
    savedGuides,
    recentGuides,
    isLoadingSaved,
    isLoadingRecent,
    hasMoreSaved,
    hasMoreRecent,
    currentTab,
  ];

  SavedGuidesApiLoaded copyWith({
    List<SavedGuideEntity>? savedGuides,
    List<SavedGuideEntity>? recentGuides,
    bool? isLoadingSaved,
    bool? isLoadingRecent,
    bool? hasMoreSaved,
    bool? hasMoreRecent,
    int? currentTab,
  }) {
    return SavedGuidesApiLoaded(
      savedGuides: savedGuides ?? this.savedGuides,
      recentGuides: recentGuides ?? this.recentGuides,
      isLoadingSaved: isLoadingSaved ?? this.isLoadingSaved,
      isLoadingRecent: isLoadingRecent ?? this.isLoadingRecent,
      hasMoreSaved: hasMoreSaved ?? this.hasMoreSaved,
      hasMoreRecent: hasMoreRecent ?? this.hasMoreRecent,
      currentTab: currentTab ?? this.currentTab,
    );
  }
}

class SavedGuidesTabLoading extends SavedGuidesState {
  final int tabIndex;
  final bool isRefresh;

  const SavedGuidesTabLoading({
    required this.tabIndex,
    this.isRefresh = false,
  });

  @override
  List<Object?> get props => [tabIndex, isRefresh];
}