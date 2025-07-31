import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/pagination_helper.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../../domain/usecases/get_saved_guides_with_sync.dart';
import '../../domain/usecases/get_recent_guides_with_sync.dart';
import '../../domain/usecases/toggle_save_guide_api.dart';
import 'saved_guides_event.dart';
import 'saved_guides_state.dart';

/// Unified BLoC that follows Clean Architecture principles
/// Uses use cases to interact with the repository layer
class UnifiedSavedGuidesBloc extends Bloc<SavedGuidesEvent, SavedGuidesState> with PaginationMixin {
  final GetSavedGuidesWithSync _getSavedGuidesWithSync;
  final GetRecentGuidesWithSync _getRecentGuidesWithSync;
  final ToggleSaveGuideApi _toggleSaveGuideApi;
  
  // Debouncer for tab changes
  Timer? _debounceTimer;

  UnifiedSavedGuidesBloc({
    required GetSavedGuidesWithSync getSavedGuidesWithSync,
    required GetRecentGuidesWithSync getRecentGuidesWithSync,
    required ToggleSaveGuideApi toggleSaveGuideApi,
  }) : _getSavedGuidesWithSync = getSavedGuidesWithSync,
       _getRecentGuidesWithSync = getRecentGuidesWithSync,
       _toggleSaveGuideApi = toggleSaveGuideApi,
       super(SavedGuidesInitial()) {
    
    on<LoadSavedGuidesFromApi>(_onLoadSavedGuides);
    on<LoadRecentGuidesFromApi>(_onLoadRecentGuides);
    on<ToggleGuideApiEvent>(_onToggleGuide);
    on<TabChangedEvent>(_onTabChanged);
  }

  Future<void> _onLoadSavedGuides(
    LoadSavedGuidesFromApi event,
    Emitter<SavedGuidesState> emit,
  ) async {
    // REFACTORED: Extract state management to reduce complexity
    final loadingState = _prepareLoadingState(
      currentState: state,
      isRefresh: event.refresh,
      targetTab: 0,
      resetSavedOffset: event.refresh,
    );
    
    // Emit loading state
    _emitLoadingState(emit, loadingState);

    // Execute the use case
    final result = await _getSavedGuidesWithSync(
      limit: event.limit,
      offset: event.refresh ? 0 : savedPagination.offset,
      forceRefresh: event.refresh,
    );
    
    // REFACTORED: Use centralized result handling
    _handleSavedGuidesResult(
      result: result,
      event: event,
      loadingState: loadingState,
      emit: emit,
    );
  }

  Future<void> _onLoadRecentGuides(
    LoadRecentGuidesFromApi event,
    Emitter<SavedGuidesState> emit,
  ) async {
    // REFACTORED: Extract state management to reduce complexity
    final loadingState = _prepareLoadingState(
      currentState: state,
      isRefresh: event.refresh,
      targetTab: 1,
      resetRecentOffset: event.refresh,
    );
    
    // Emit loading state
    _emitLoadingState(emit, loadingState);

    // Execute the use case
    final result = await _getRecentGuidesWithSync(
      limit: event.limit,
      offset: event.refresh ? 0 : recentPagination.offset,
      forceRefresh: event.refresh,
    );
    
    // REFACTORED: Use centralized result handling
    _handleRecentGuidesResult(
      result: result,
      event: event,
      loadingState: loadingState,
      emit: emit,
    );
  }

  Future<void> _onToggleGuide(
    ToggleGuideApiEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    final result = await _toggleSaveGuideApi(
      guideId: event.guideId,
      save: event.save,
    );
    
    result.fold(
      (failure) {
        if (failure.runtimeType.toString().contains('Authentication')) {
          emit(const SavedGuidesAuthRequired(
            message: 'You need to be signed in to save guides',
            isForSavedGuides: true,
          ));
        } else {
          emit(SavedGuidesError(message: failure.message));
        }
      },
      (updatedGuide) {
        final currentState = state;
        if (currentState is SavedGuidesApiLoaded) {
          // Update the guide in both lists
          final updatedSavedGuides = _updateGuideInList(
            currentState.savedGuides,
            updatedGuide,
            event.save,
          );

          final updatedRecentGuides = _updateGuideInList(
            currentState.recentGuides,
            updatedGuide,
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
      },
    );
  }

  Future<void> _onTabChanged(
    TabChangedEvent event,
    Emitter<SavedGuidesState> emit,
  ) async {
    // TIMER RESOURCE LEAK FIX: Proper cleanup and error handling
    
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null; // Clear reference to prevent memory leaks
    
    // Use a more robust approach with proper error handling
    final completer = Completer<void>();
    
    try {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        try {
          // Check if the BLoC is still active and emitter is valid
          if (!emit.isDone && !completer.isCompleted) {
            _handleTabChangeLogic(event, emit);
          }
        } catch (e) {
          // Handle any errors in tab change logic
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        } finally {
          // Always complete the completer to prevent hanging
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });
      
      // Wait for debounced operation with timeout protection
      await completer.future.timeout(
        const Duration(seconds: 1), // Prevent hanging indefinitely
        onTimeout: () {
          // If timeout occurs, cancel timer and complete
          _debounceTimer?.cancel();
          _debounceTimer = null;
        },
      );
    } catch (e) {
      // Clean up resources on any error
      _debounceTimer?.cancel();
      _debounceTimer = null;
      rethrow;
    }
  }
  
  /// EXTRACTED METHOD: Handles tab change logic separately
  /// Improves testability and reduces complexity in timer callback
  void _handleTabChangeLogic(
    TabChangedEvent event,
    Emitter<SavedGuidesState> emit,
  ) {
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

    // Always load data for the selected tab when switching
    if (event.tabIndex == 0) {
      add(const LoadSavedGuidesFromApi());
    } else {
      add(const LoadRecentGuidesFromApi());
    }
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

  /// EXTRACTED METHOD: Prepares loading state data to reduce duplication
  /// Centralizes the logic for preserving existing data and managing offsets
  _LoadingStateData _prepareLoadingState({
    required SavedGuidesState currentState,
    required bool isRefresh,
    required int targetTab,
    bool resetSavedOffset = false,
    bool resetRecentOffset = false,
  }) {
    List<SavedGuideEntity> currentSavedGuides = [];
    List<SavedGuideEntity> currentRecentGuides = [];

    // Preserve existing data if not refreshing
    if (currentState is SavedGuidesApiLoaded && !isRefresh) {
      currentSavedGuides = List.from(currentState.savedGuides);
      currentRecentGuides = List.from(currentState.recentGuides);
    }

    // Reset offsets if requested
    if (resetSavedOffset) {
      resetSavedPagination();
    }
    if (resetRecentOffset) {
      resetRecentPagination();
    }

    return _LoadingStateData(
      currentSavedGuides: currentSavedGuides,
      currentRecentGuides: currentRecentGuides,
      currentState: currentState,
      targetTab: targetTab,
      isRefresh: isRefresh,
    );
  }

  /// EXTRACTED METHOD: Emits appropriate loading state
  /// Reduces complexity in main event handlers
  void _emitLoadingState(
    Emitter<SavedGuidesState> emit,
    _LoadingStateData loadingData,
  ) {
    if (loadingData.currentState is SavedGuidesApiLoaded) {
      final currentState = loadingData.currentState as SavedGuidesApiLoaded;
      if (loadingData.targetTab == 0) {
        emit(currentState.copyWith(isLoadingSaved: true));
      } else {
        emit(currentState.copyWith(isLoadingRecent: true));
      }
    } else {
      emit(SavedGuidesTabLoading(
        tabIndex: loadingData.targetTab,
        isRefresh: loadingData.isRefresh,
      ));
    }
  }

  /// EXTRACTED METHOD: Handles saved guides result processing
  /// Centralizes result handling logic to reduce duplication
  void _handleSavedGuidesResult({
    required dynamic result,
    required LoadSavedGuidesFromApi event,
    required _LoadingStateData loadingState,
    required Emitter<SavedGuidesState> emit,
  }) {
    result.fold(
      (failure) => _handleFailure(failure, emit, isForSavedGuides: true),
      (newGuides) {
        // Update saved guides list
        final updatedSavedGuides = _updateGuidesList(
          currentGuides: loadingState.currentSavedGuides,
          newGuides: newGuides,
          isRefresh: event.refresh,
          currentOffset: savedPagination.offset,
        );

        // Update pagination for next load
        if (!event.refresh && newGuides.isNotEmpty) {
          nextSavedPage();
        }

        // Check if there are more items
        final hasMore = newGuides.length >= event.limit;

        emit(SavedGuidesApiLoaded(
          savedGuides: updatedSavedGuides,
          recentGuides: loadingState.currentRecentGuides,
          hasMoreSaved: hasMore,
          currentTab: loadingState.currentState is SavedGuidesApiLoaded 
              ? (loadingState.currentState as SavedGuidesApiLoaded).currentTab 
              : 0,
        ));
      },
    );
  }

  /// EXTRACTED METHOD: Handles recent guides result processing
  /// Centralizes result handling logic to reduce duplication
  void _handleRecentGuidesResult({
    required dynamic result,
    required LoadRecentGuidesFromApi event,
    required _LoadingStateData loadingState,
    required Emitter<SavedGuidesState> emit,
  }) {
    result.fold(
      (failure) => _handleFailure(failure, emit, isForSavedGuides: false),
      (newGuides) {
        // Update recent guides list
        final updatedRecentGuides = _updateGuidesList(
          currentGuides: loadingState.currentRecentGuides,
          newGuides: newGuides,
          isRefresh: event.refresh,
          currentOffset: recentPagination.offset,
        );

        // Update pagination for next load
        if (!event.refresh && newGuides.isNotEmpty) {
          nextRecentPage();
        }

        // Check if there are more items
        final hasMore = newGuides.length >= event.limit;

        emit(SavedGuidesApiLoaded(
          savedGuides: loadingState.currentSavedGuides,
          recentGuides: updatedRecentGuides,
          hasMoreRecent: hasMore,
          currentTab: loadingState.currentState is SavedGuidesApiLoaded 
              ? (loadingState.currentState as SavedGuidesApiLoaded).currentTab 
              : 1,
        ));
      },
    );
  }

  /// EXTRACTED METHOD: Centralizes failure handling
  /// Reduces code duplication across different result handlers
  void _handleFailure(
    dynamic failure,
    Emitter<SavedGuidesState> emit, {
    required bool isForSavedGuides,
  }) {
    if (failure.runtimeType.toString().contains('Authentication')) {
      emit(SavedGuidesAuthRequired(
        message: isForSavedGuides 
            ? 'You need to be signed in to view saved guides'
            : 'You need to be signed in to view recent guides',
        isForSavedGuides: isForSavedGuides,
      ));
    } else {
      emit(SavedGuidesError(message: failure.message));
    }
  }

  /// EXTRACTED METHOD: Updates guides list with new data
  /// Centralizes the pagination logic for both saved and recent guides
  List<SavedGuideEntity> _updateGuidesList({
    required List<SavedGuideEntity> currentGuides,
    required List<SavedGuideEntity> newGuides,
    required bool isRefresh,
    required int currentOffset,
  }) {
    if (isRefresh || currentOffset == 0) {
      return newGuides;
    } else {
      return [...currentGuides, ...newGuides];
    }
  }

  @override
  Future<void> close() {
    // TIMER RESOURCE LEAK FIX: Ensure complete cleanup
    _debounceTimer?.cancel();
    _debounceTimer = null; // Clear reference to prevent memory leaks
    return super.close();
  }
}

/// Data class to hold loading state information
/// Reduces parameter passing complexity
class _LoadingStateData {
  final List<SavedGuideEntity> currentSavedGuides;
  final List<SavedGuideEntity> currentRecentGuides;
  final SavedGuidesState currentState;
  final int targetTab;
  final bool isRefresh;

  const _LoadingStateData({
    required this.currentSavedGuides,
    required this.currentRecentGuides,
    required this.currentState,
    required this.targetTab,
    required this.isRefresh,
  });
}