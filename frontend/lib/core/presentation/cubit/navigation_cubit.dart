import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

/// Navigation states for bottom navigation
abstract class NavigationState extends Equatable {
  const NavigationState();
  
  @override
  List<Object> get props => [];
}

class NavigationInitial extends NavigationState {
  final int selectedIndex;
  
  const NavigationInitial({this.selectedIndex = 0});
  
  @override
  List<Object> get props => [selectedIndex];
}

class NavigationTabChanged extends NavigationState {
  final int selectedIndex;
  final String routeName;
  
  const NavigationTabChanged({
    required this.selectedIndex, 
    required this.routeName,
  });
  
  @override
  List<Object> get props => [selectedIndex, routeName];
}

/// Navigation events for bottom navigation
abstract class NavigationEvent extends Equatable {
  const NavigationEvent();
  
  @override
  List<Object> get props => [];
}

class TabSelected extends NavigationEvent {
  final int index;
  final String routeName;
  
  const TabSelected({required this.index, required this.routeName});
  
  @override
  List<Object> get props => [index, routeName];
}

class NavigationInitialized extends NavigationEvent {
  final int initialIndex;
  
  const NavigationInitialized({this.initialIndex = 0});
  
  @override
  List<Object> get props => [initialIndex];
}

/// Navigation Cubit for managing bottom navigation state
/// 
/// Features:
/// - Track currently selected tab index
/// - Handle tab navigation with route awareness
/// - Maintain navigation history for back gesture support
/// - Provide state persistence across app lifecycle
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(const NavigationInitial());

  /// Available navigation routes mapped to their indices
  static const Map<int, String> indexToRoute = {
    0: '/',
    1: '/generate-study', 
    2: '/saved',
    3: '/settings',
  };

  static const Map<String, int> routeToIndex = {
    '/': 0,
    '/generate-study': 1,
    '/saved': 2,
    '/settings': 3,
  };

  int _selectedIndex = 0;
  List<int> _navigationHistory = [0];

  /// Get current selected tab index
  int get selectedIndex => _selectedIndex;

  /// Get navigation history for back gesture handling
  List<int> get navigationHistory => List.unmodifiable(_navigationHistory);

  /// Initialize navigation with optional starting index
  void initialize({int initialIndex = 0}) {
    _selectedIndex = initialIndex;
    _navigationHistory = [initialIndex];
    emit(NavigationInitial(selectedIndex: initialIndex));
  }

  /// Select a tab by index
  void selectTab(int index) {
    if (index < 0 || index >= indexToRoute.length) {
      return; // Invalid index
    }

    if (index == _selectedIndex) {
      return; // Same tab selected, no change needed
    }

    _selectedIndex = index;
    
    // Update navigation history (keep last 10 entries)
    _navigationHistory.add(index);
    if (_navigationHistory.length > 10) {
      _navigationHistory.removeAt(0);
    }

    final routeName = indexToRoute[index]!;
    emit(NavigationTabChanged(
      selectedIndex: index,
      routeName: routeName,
    ));
  }

  /// Select tab by route name
  void selectTabByRoute(String route) {
    final index = routeToIndex[route];
    if (index != null) {
      selectTab(index);
    }
  }

  /// Handle back navigation (for Android back button)
  bool handleBackNavigation() {
    if (_navigationHistory.length > 1) {
      // Remove current tab from history
      _navigationHistory.removeLast();
      
      // Navigate to previous tab
      final previousIndex = _navigationHistory.last;
      _selectedIndex = previousIndex;
      
      final routeName = indexToRoute[previousIndex]!;
      emit(NavigationTabChanged(
        selectedIndex: previousIndex,
        routeName: routeName,
      ));
      
      return true; // Handled by navigation
    }
    
    return false; // Let system handle (exit app)
  }

  /// Reset navigation to home tab
  void resetToHome() {
    selectTab(0);
  }

  /// Check if given route corresponds to a main navigation tab
  bool isMainNavigationRoute(String route) => routeToIndex.containsKey(route);

  /// Get tab index for route (returns null if not a main nav route)
  int? getTabIndexForRoute(String route) {
    final index = routeToIndex[route];
    print('🗺️ [NAV_CUBIT] Route "$route" → Index: $index');
    print('🗺️ [NAV_CUBIT] Available routes: $routeToIndex');
    return index;
  }

  /// Get route name for tab index
  String? getRouteForTabIndex(int index) => indexToRoute[index];
}