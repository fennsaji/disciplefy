import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as flutter_services;
import 'package:showcaseview/showcaseview.dart';
import '../../constants/app_fonts.dart';
import '../../animations/app_animations.dart';
import '../../localization/app_localizations.dart';
import '../../../features/walkthrough/domain/walkthrough_screen.dart';
import '../../../features/walkthrough/presentation/showcase_keys.dart';
import '../../../features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Navigation tab data model for bottom navigation
class NavTab {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String semanticLabel;

  const NavTab({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.semanticLabel,
  });
}

/// Disciplefy Bottom Navigation Bar - Theme Aware
///
/// Features:
/// ✅ Fixed overflow issues with proper SafeArea usage
/// ✅ Theme-aware background with rounded top corners
/// ✅ Dynamic theme colors: Active (primary), Inactive (onSurface)
/// ✅ Top border for visual separation
/// ✅ No unnecessary padding or margins
/// ✅ No swipe animations - uses IndexedStack
/// ✅ Proper positioning to prevent bottom gaps
class DisciplefyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavTab> tabs;

  const DisciplefyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  /// Default navigation tabs for Disciplefy app
  static const List<NavTab> defaultTabs = [
    NavTab(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      semanticLabel:
          'Navigate to Home screen. Shows daily verse and study recommendations.',
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: 'Generate',
      semanticLabel:
          'Navigate to Study Generation screen. Create new Bible study guides.',
    ),
    NavTab(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: 'Topics',
      semanticLabel:
          'Navigate to Study Topics screen. Browse learning paths and continue your studies.',
    ),
    NavTab(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Community',
      semanticLabel:
          'Navigate to Community screen. Join fellowships and connect with other believers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Compute arrow alignment for Community tab dynamically so the arrow
    // accurately points at the tab icon regardless of screen width.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double tooltipWidth = math.min(280.0, screenWidth - 48);
    const double arrowWidth = 20.0;
    // Community is the 4th of 4 equal tabs → center at 7/8 of screen width.
    final double tabCenterX = screenWidth * 7.0 / 8.0;
    // showcaseview clamps the tooltip so its right edge ≤ screen width.
    final double tooltipLeft =
        (screenWidth - tooltipWidth).clamp(0.0, screenWidth);
    final double fromLeft = (tabCenterX - tooltipLeft)
        .clamp(arrowWidth / 2, tooltipWidth - arrowWidth / 2);
    final double ax =
        ((fromLeft - arrowWidth / 2) / (tooltipWidth - arrowWidth) * 2 - 1)
            .clamp(-1.0, 1.0);
    final Alignment communityArrowAlignment = Alignment(ax, 0.0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false, // Don't apply SafeArea to top
        child: SizedBox(
          height: 60, // Fixed height to prevent overflow
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = currentIndex == index;

              final navItem = _BottomNavItem(
                tab: tab,
                isSelected: isSelected,
                onTap: () => _handleTap(context, index),
              );

              // Wrap Generate, Topics, and Community tabs with walkthrough
              // tooltips so the home screen walkthrough highlights each nav item.
              if (tab.label == 'Generate') {
                return Expanded(
                  child: WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.homeGenerateTab,
                    title: AppLocalizations.of(context)!
                        .walkthroughHomeGenerateTitle,
                    description: AppLocalizations.of(context)!
                        .walkthroughHomeGenerateDesc,
                    screen: WalkthroughScreen.home,
                    stepNumber: 3,
                    totalSteps: 5,
                    onNext: () => ShowCaseWidget.of(context).next(),
                    child: navItem,
                  ),
                );
              }

              if (tab.label == 'Topics') {
                return Expanded(
                  child: WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.homeTopicsTab,
                    title: AppLocalizations.of(context)!
                        .walkthroughHomeTopicsTitle,
                    description:
                        AppLocalizations.of(context)!.walkthroughHomeTopicsDesc,
                    screen: WalkthroughScreen.home,
                    stepNumber: 4,
                    totalSteps: 5,
                    onNext: () => ShowCaseWidget.of(context).next(),
                    child: navItem,
                  ),
                );
              }

              if (tab.label == 'Community') {
                return Expanded(
                  child: WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.homeCommunityTab,
                    title: AppLocalizations.of(context)!
                        .walkthroughCommunityNavTitle,
                    description: AppLocalizations.of(context)!
                        .walkthroughCommunityNavDesc,
                    screen: WalkthroughScreen.home,
                    stepNumber: 5,
                    totalSteps: 5,
                    // Community tab is rightmost — shift arrow right so it
                    // points accurately at the tab icon.
                    arrowAlignment: communityArrowAlignment,
                    onNext: () => ShowCaseWidget.of(context).next(),
                    child: navItem,
                  ),
                );
              }

              return Expanded(child: navItem);
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, int index) {
    if (index != currentIndex) {
      // Provide haptic feedback for better UX
      flutter_services.HapticFeedback.lightImpact();
      onTap(index);
    }
  }
}

/// Individual bottom navigation item with Disciplefy styling and animations
class _BottomNavItem extends StatefulWidget {
  final NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Semantics(
          label: widget.tab.semanticLabel,
          button: true,
          selected: widget.isSelected,
          enabled: true,
          focusable: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with animated background indicator
                AnimatedContainer(
                  duration: AppAnimations.fast,
                  curve: AppAnimations.defaultCurve,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? activeColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedSwitcher(
                    duration: AppAnimations.fast,
                    switchInCurve: AppAnimations.defaultCurve,
                    switchOutCurve: AppAnimations.defaultCurve,
                    child: Icon(
                      widget.isSelected && widget.tab.activeIcon != null
                          ? widget.tab.activeIcon!
                          : widget.tab.icon,
                      key: ValueKey(widget.isSelected),
                      size: 18,
                      color: widget.isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // Label with animated color
                AnimatedDefaultTextStyle(
                  duration: AppAnimations.fast,
                  curve: AppAnimations.defaultCurve,
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isSelected ? activeColor : inactiveColor,
                  ),
                  child: Text(
                    widget.tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
