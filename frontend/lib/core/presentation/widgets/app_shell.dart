import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/system_config_service.dart';
import '../../../features/tokens/presentation/bloc/token_bloc.dart';
import '../../../features/tokens/presentation/bloc/token_state.dart';
import 'bottom_nav.dart' as bottom_nav;

/// Main App Shell with Bottom Navigation
///
/// Features:
/// - Persistent bottom navigation using IndexedStack
/// - Bottom navigation with Disciplefy branding
/// - Android back button handling
/// - Smooth fade animation when switching tabs
/// - Memory-efficient screen management
/// - Accessibility support
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _previousIndex = 0;
  int? _pendingTabIndex;
  bool _showLoadingIndicator = false;
  int?
      _waitingForIndex; // Track which index we're waiting for navigation to complete
  Timer? _loadingTimeout; // Safety timeout to prevent infinite loading

  static const _loadingTimeoutDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    // Quick cross-fade for snappy tab transitions
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _setupAnimations();
    _animController.addStatusListener(_onAnimationStatusChanged);
    _animController.value = 1.0; // Start at end position (visible)
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (!mounted) return;

    if (status == AnimationStatus.dismissed && _pendingTabIndex != null) {
      final targetIndex = _pendingTabIndex!;
      _pendingTabIndex = null;

      // Show loading indicator and track what we're waiting for
      setState(() {
        _showLoadingIndicator = true;
        _waitingForIndex = targetIndex;
      });

      // Start safety timeout to prevent infinite loading
      _startLoadingTimeout();

      // Trigger navigation - this returns immediately but router guard runs async
      widget.navigationShell.goBranch(targetIndex);

      // DON'T start fade-in here - it will be triggered in build()
      // when we detect currentIndex has changed to targetIndex
    }
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(_loadingTimeoutDuration, () {
      if (mounted && _showLoadingIndicator) {
        // Timeout reached - hide loading and show current content
        setState(() {
          _showLoadingIndicator = false;
          _waitingForIndex = null;
          _previousIndex = widget.navigationShell.currentIndex;
        });
        _animController.value = 1.0; // Show content immediately
      }
    });
  }

  void _cancelLoadingTimeout() {
    _loadingTimeout?.cancel();
    _loadingTimeout = null;
  }

  void _setupAnimations() {
    // Fade through: cross-fade animation (Material Design recommended)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));

    // Subtle scale: 92% → 100% for incoming content (Material Motion)
    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _cancelLoadingTimeout();
    _animController.removeStatusListener(_onAnimationStatusChanged);
    _animController.stop();
    _animController.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    // Map the visible tab index to the actual branch index
    final branchIndex = _mapTabIndexToBranchIndex(index);

    // Ignore if already on this tab and not waiting for anything
    if (branchIndex == widget.navigationShell.currentIndex &&
        _pendingTabIndex == null &&
        _waitingForIndex == null) {
      return;
    }

    // Allow interrupting ongoing animation or loading with new tab selection
    _pendingTabIndex = branchIndex;

    // If currently showing loading indicator (animation is dismissed),
    // directly trigger navigation to the new tab
    if (_showLoadingIndicator &&
        _animController.status == AnimationStatus.dismissed) {
      final targetIndex = _pendingTabIndex!;
      _pendingTabIndex = null;
      setState(() {
        _waitingForIndex = targetIndex;
      });
      widget.navigationShell.goBranch(targetIndex);
      return;
    }

    // If animation is already reversing, just update pending index (handled above)
    // Otherwise, start the fade-out animation
    if (_animController.status != AnimationStatus.reverse) {
      _animController.reverse();
    }
  }

  /// Maps visible tab index to actual router branch index
  /// Handles cases where Generate tab (branch 1) or Topics tab (branch 2) are hidden
  int _mapTabIndexToBranchIndex(int tabIndex) {
    final tabs = _getFilteredTabs();

    // Determine which tabs are visible
    final hasHome = tabs.any((tab) => tab.label == 'Home');
    final hasGenerate = tabs.any((tab) => tab.label == 'Generate');
    final hasTopics = tabs.any((tab) => tab.label == 'Topics');

    // Case 1: All tabs visible - 1:1 mapping
    if (tabs.length == 3) {
      return tabIndex; // Home→0, Generate→1, Topics→2
    }

    // Case 2: Only Home visible
    if (tabs.length == 1) {
      return 0; // Home→0
    }

    // Case 3: Two tabs visible - determine which combination
    if (hasHome && hasGenerate && !hasTopics) {
      // Home + Generate visible, Topics hidden
      return tabIndex; // Home→0, Generate→1
    }

    if (hasHome && !hasGenerate && hasTopics) {
      // Home + Topics visible, Generate hidden
      return tabIndex == 0 ? 0 : 2; // Home→0, Topics→2
    }

    // Fallback to home
    return 0;
  }

  /// Maps router branch index to visible tab index
  /// Handles cases where Generate tab (branch 1) or Topics tab (branch 2) are hidden
  int _mapBranchIndexToTabIndex(int branchIndex) {
    final tabs = _getFilteredTabs();

    // Determine which tabs are visible
    final hasHome = tabs.any((tab) => tab.label == 'Home');
    final hasGenerate = tabs.any((tab) => tab.label == 'Generate');
    final hasTopics = tabs.any((tab) => tab.label == 'Topics');

    // Case 1: All tabs visible - 1:1 mapping
    if (tabs.length == 3) {
      return branchIndex; // 0→Home(0), 1→Generate(1), 2→Topics(2)
    }

    // Case 2: Only Home visible
    if (tabs.length == 1) {
      return 0; // Always map to Home
    }

    // Case 3: Two tabs visible - determine which combination
    if (hasHome && hasGenerate && !hasTopics) {
      // Home + Generate visible, Topics hidden
      if (branchIndex == 0) return 0; // Home→0
      if (branchIndex == 1) return 1; // Generate→1
      // If navigating to hidden Topics (branch 2), redirect to Home
      return 0;
    }

    if (hasHome && !hasGenerate && hasTopics) {
      // Home + Topics visible, Generate hidden
      if (branchIndex == 0) return 0; // Home→0
      if (branchIndex == 2) return 1; // Topics→1
      // If navigating to hidden Generate (branch 1), redirect to Home
      return 0;
    }

    // Fallback to home
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // Check if our navigation completed (router guard finished async work)
    if (_waitingForIndex != null && currentIndex == _waitingForIndex) {
      // Schedule state update for next frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _waitingForIndex != null) {
          _cancelLoadingTimeout(); // Navigation succeeded, cancel timeout
          setState(() {
            _showLoadingIndicator = false;
            _previousIndex = currentIndex;
            _waitingForIndex = null;
          });
          _animController.value = 0.0;
          _animController.forward();
        }
      });
    }

    // Detect tab change from external navigation (e.g., back button)
    // Only handle if no pending animation, not waiting for navigation, and controller is idle
    if (_waitingForIndex == null &&
        currentIndex != _previousIndex &&
        _pendingTabIndex == null &&
        _animController.status == AnimationStatus.completed) {
      _previousIndex = currentIndex;

      // Quick fade in when tab changes externally
      _animController.value = 0.0;
      _animController.forward();
    }

    // Note: Achievement unlock dialog is handled globally in main.dart
    // to ensure it works for ALL routes including Memory Verses outside AppShell
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Main content with animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: widget.navigationShell,
              ),
            ),
            // Loading indicator overlay - shown during async navigation
            if (_showLoadingIndicator)
              Semantics(
                label: 'Loading content',
                liveRegion: true,
                container: true,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3,
                      semanticsLabel: 'Loading',
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: bottom_nav.DisciplefyBottomNav(
          currentIndex: _mapBranchIndexToTabIndex(currentIndex),
          tabs: _getFilteredTabs(),
          onTap: _onTabChange,
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (widget.navigationShell.currentIndex > 0) {
      // Go back to home tab if not already there
      widget.navigationShell.goBranch(0);
    } else {
      // Exit the app if already on home tab
      SystemNavigator.pop();
    }
  }

  /// Get filtered tabs list based on feature flags
  /// - Hides Generate tab if all study modes and AI Discipler are disabled
  /// - Hides Topics tab if learning_paths feature is disabled
  List<bottom_nav.NavTab> _getFilteredTabs() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }

    final systemConfigService = sl<SystemConfigService>();

    // Check all study modes
    final studyModes = [
      'quick_read_mode',
      'standard_study_mode',
      'deep_dive_mode',
      'lectio_divina_mode',
      'sermon_outline_mode',
    ];

    // Check if ALL study modes are disabled
    final allStudyModesDisabled = studyModes.every(
      (mode) => !systemConfigService.isFeatureEnabled(mode, userPlan),
    );

    // Check if AI Discipler is disabled
    final aiDisciplerDisabled =
        !systemConfigService.isFeatureEnabled('ai_discipler', userPlan);

    // Check if learning paths is disabled
    final learningPathsDisabled =
        !systemConfigService.isFeatureEnabled('learning_paths', userPlan);

    // Hide Generate tab if both ALL study modes are disabled AND AI Discipler is disabled
    final shouldHideGenerate = allStudyModesDisabled && aiDisciplerDisabled;

    // Hide Topics tab if learning_paths feature is disabled
    final shouldHideTopics = learningPathsDisabled;

    // Build filtered tabs list
    final filteredTabs = <bottom_nav.NavTab>[];

    // Always include Home tab
    filteredTabs.add(bottom_nav.DisciplefyBottomNav.defaultTabs[0]);

    // Conditionally add Generate tab
    if (!shouldHideGenerate) {
      filteredTabs.add(bottom_nav.DisciplefyBottomNav.defaultTabs[1]);
    }

    // Conditionally add Topics tab
    if (!shouldHideTopics) {
      filteredTabs.add(bottom_nav.DisciplefyBottomNav.defaultTabs[2]);
    }

    return filteredTabs;
  }
}

/// Custom page transition for smooth navigation
class SlidePageRoute<T> extends PageRoute<T> {
  final Widget child;
  final AxisDirection direction;

  SlidePageRoute({
    required this.child,
    this.direction = AxisDirection.left,
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    Offset begin;
    const Offset end = Offset.zero;

    switch (direction) {
      case AxisDirection.up:
        begin = const Offset(0.0, 1.0);
        break;
      case AxisDirection.down:
        begin = const Offset(0.0, -1.0);
        break;
      case AxisDirection.right:
        begin = const Offset(-1.0, 0.0);
        break;
      case AxisDirection.left:
      default:
        begin = const Offset(1.0, 0.0);
        break;
    }

    final tween = Tween(begin: begin, end: end);
    final offsetAnimation = animation.drive(tween);

    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}
