import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/unified_study_guides_service.dart';
import '../../domain/entities/saved_guide_entity.dart';
import 'saved_guides_event.dart';
import 'saved_guides_state.dart';

/// Enhanced BLoC for handling API-based study guides with pagination and tab management
class SavedGuidesApiBloc extends Bloc<SavedGuidesEvent, SavedGuidesState> {
  final UnifiedStudyGuidesService _unifiedService;
  
  // Pagination tracking
  int _savedOffset = 0;
  int _recentOffset = 0;
  final int _pageSize = 20;
  
  // Debouncer for tab changes
  Timer? _debounceTimer;

  SavedGuidesApiBloc({
    UnifiedStudyGuidesService? unifiedService,
  }) : _unifiedService = unifiedService ?? UnifiedStudyGuidesService(),
       super(SavedGuidesInitial()) {
    
    on<LoadSavedGuidesFromApi>(_onLoadSavedGuidesFromApi);
    on<LoadRecentGuidesFromApi>(_onLoadRecentGuidesFromApi);
    on<ToggleGuideApiEvent>(_onToggleGuideApi);
    on<TabChangedEvent>(_onTabChanged);
  }

  Future<void> _onLoadSavedGuidesFromApi(
    LoadSavedGuidesFromApi event,
    Emitter<SavedGuidesState> emit,
  ) async {

    final currentState = state;
    List<SavedGuideEntity> currentSavedGuides = [];
    List<SavedGuideEntity> currentRecentGuides = [];

    // Preserve existing data if not refreshing
    if (currentState is SavedGuidesApiLoaded && !event.refresh) {
      currentSavedGuides = List.from(currentState.savedGuides);
      currentRecentGuides = List.from(currentState.recentGuides);
    }

    // Reset offset if refreshing
    if (event.refresh) {
      _savedOffset = 0;
    }

    // Show loading state
    if (currentState is SavedGuidesApiLoaded) {
      emit(currentState.copyWith(isLoadingSaved: true));
    } else {
      emit(const SavedGuidesTabLoading(tabIndex: 0, isRefresh: true));
    }

    try {
      final result = await _unifiedService.fetchStudyGuides(
        saved: true,
        limit: event.limit,
        offset: event.refresh ? 0 : _savedOffset,
      );
      
      if (result.requiresAuth) {
        emit(const SavedGuidesAuthRequired(
          message: 'You need to be signed in to view saved guides',
          isForSavedGuides: true,
        ));
        return;
      }
      
      if (!result.isSuccess) {
        emit(SavedGuidesError(message: result.error ?? 'Failed to load saved guides'));
        return;
      }

      // Convert API models to entities
      final newGuides = result.guides!.map((model) => model.toEntity()).toList();

      // Update saved guides list
      List<SavedGuideEntity> updatedSavedGuides;
      if (event.refresh || _savedOffset == 0) {
        updatedSavedGuides = newGuides;
      } else {
        updatedSavedGuides = [...currentSavedGuides, ...newGuides];
      }

      // Update offset for next load
      _savedOffset = updatedSavedGuides.length;

      // Check if there are more items
      final hasMore = newGuides.length >= event.limit;

      emit(SavedGuidesApiLoaded(
        savedGuides: updatedSavedGuides,
        recentGuides: currentRecentGuides,
        hasMoreSaved: hasMore,
        currentTab: currentState is SavedGuidesApiLoaded ? currentState.currentTab : 0,
      ));

    } catch (e) {
      emit(SavedGuidesError(message: 'Failed to load saved guides: ${e.toString()}'));
    }
  }

  Future<void> _onLoadRecentGuidesFromApi(
    LoadRecentGuidesFromApi event,
    Emitter<SavedGuidesState> emit,
  ) async {

    final currentState = state;
    List<SavedGuideEntity> currentSavedGuides = [];
    List<SavedGuideEntity> currentRecentGuides = [];

    // Preserve existing data if not refreshing
    if (currentState is SavedGuidesApiLoaded && !event.refresh) {
      currentSavedGuides = List.from(currentState.savedGuides);
      currentRecentGuides = List.from(currentState.recentGuides);
    }

    // Reset offset if refreshing
    if (event.refresh) {
      _recentOffset = 0;
    }

    // Show loading state
    if (currentState is SavedGuidesApiLoaded) {
      emit(currentState.copyWith(isLoadingRecent: true));
    } else {
      emit(const SavedGuidesTabLoading(tabIndex: 1, isRefresh: true));
    }

    try {
      final result = await _unifiedService.fetchStudyGuides(
        limit: event.limit,
        offset: event.refresh ? 0 : _recentOffset,
      );
      
      if (result.requiresAuth) {
        emit(const SavedGuidesAuthRequired(
          message: 'You need to be signed in to view recent guides',
          isForSavedGuides: false,
        ));
        return;
      }
      
      if (!result.isSuccess) {
        emit(SavedGuidesError(message: result.error ?? 'Failed to load recent guides'));
        return;
      }

      // Convert API models to entities
      final newGuides = result.guides!.map((model) => model.toEntity()).toList();

      // Update recent guides list
      List<SavedGuideEntity> updatedRecentGuides;
      if (event.refresh || _recentOffset == 0) {
        updatedRecentGuides = newGuides;
      } else {
        updatedRecentGuides = [...currentRecentGuides, ...newGuides];
      }

      // Update offset for next load
      _recentOffset = updatedRecentGuides.length;

      // Check if there are more items
      final hasMore = newGuides.length >= event.limit;

      emit(SavedGuidesApiLoaded(
        savedGuides: currentSavedGuides,
        recentGuides: updatedRecentGuides,
        hasMoreRecent: hasMore,
        currentTab: currentState is SavedGuidesApiLoaded ? currentState.currentTab : 1,
      ));

    } catch (e) {
      emit(SavedGuidesError(message: 'Failed to load recent guides: ${e.toString()}'));
    }
  }

  Future<void> _onToggleGuideApi(
    ToggleGuideApiEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    try {
      final result = await _unifiedService.toggleSaveGuide(
        guideId: event.guideId,
        save: event.save,
      );
      
      if (result.requiresAuth) {
        emit(const SavedGuidesAuthRequired(
          message: 'You need to be signed in to save guides',
          isForSavedGuides: true,
        ));
        return;
      }
      
      if (!result.isSuccess) {
        emit(SavedGuidesError(message: result.error ?? 'Failed to save guide'));
        return;
      }
      
      final updatedGuide = result.guides!.first;

      final currentState = state;
      if (currentState is SavedGuidesApiLoaded) {
        // Update the guide in both lists
        final updatedSavedGuides = _updateGuideInList(
          currentState.savedGuides,
          updatedGuide.toEntity(),
          event.save,
        );

        final updatedRecentGuides = _updateGuideInList(
          currentState.recentGuides,
          updatedGuide.toEntity(),
          null, // Don't remove from recent, just update
        );

        emit(currentState.copyWith(
          savedGuides: updatedSavedGuides,
          recentGuides: updatedRecentGuides,
        ));

        emit(SavedGuidesActionSuccess(
          message: event.save ? 'Guide saved successfully' : 'Guide removed from saved',
        ));
      }

    } catch (e) {
      emit(SavedGuidesError(message: 'Failed to ${event.save ? 'save' : 'remove'} guide: ${e.toString()}'));
    }
  }

  void _onTabChanged(
    TabChangedEvent event,
    Emitter<SavedGuidesState> emit,
  ) {
    // Debounce tab changes to avoid excessive API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final currentState = state;
      
      if (currentState is SavedGuidesApiLoaded) {
        emit(currentState.copyWith(currentTab: event.tabIndex));
      } else {
        emit(SavedGuidesApiLoaded(
          savedGuides: const [],
          recentGuides: const [],
          currentTab: event.tabIndex,
        ));
      }

      // Load data for the selected tab if empty
      if (event.tabIndex == 0) {
        // Saved tab
        if (currentState is! SavedGuidesApiLoaded || currentState.savedGuides.isEmpty) {
          add(const LoadSavedGuidesFromApi(refresh: true));
        }
      } else {
        // Recent tab
        if (currentState is! SavedGuidesApiLoaded || currentState.recentGuides.isEmpty) {
          add(const LoadRecentGuidesFromApi(refresh: true));
        }
      }
    });
  }

  /// Helper method to update a guide in a list
  List<SavedGuideEntity> _updateGuideInList(
    List<SavedGuideEntity> list,
    SavedGuideEntity updatedGuide,
    bool? shouldInclude,
  ) {
    final updatedList = list.where((guide) => guide.id != updatedGuide.id).toList();
    
    if (shouldInclude == true) {
      // Add to the beginning of the list
      updatedList.insert(0, updatedGuide);
    } else if (shouldInclude == null) {
      // Just update the existing guide
      final existingIndex = list.indexWhere((guide) => guide.id == updatedGuide.id);
      if (existingIndex >= 0) {
        updatedList.insert(existingIndex, updatedGuide);
      }
    }
    // If shouldInclude is false, guide is removed (already filtered out above)
    
    return updatedList;
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _unifiedService.dispose();
    return super.close();
  }
}