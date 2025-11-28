import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as flutter_services;
import '../../constants/app_fonts.dart';

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
  ];

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
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

                  return Expanded(
                    child: _BottomNavItem(
                      tab: tab,
                      isSelected: isSelected,
                      onTap: () => _handleTap(context, index),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

  void _handleTap(BuildContext context, int index) {
    if (index != currentIndex) {
      // Provide haptic feedback for better UX
      flutter_services.HapticFeedback.lightImpact();
      onTap(index);
    }
  }
}

/// Individual bottom navigation item with Disciplefy styling
class _BottomNavItem extends StatelessWidget {
  final NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: activeColor.withOpacity(0.1),
        highlightColor: activeColor.withOpacity(0.05),
        child: Semantics(
          label: tab.semanticLabel,
          button: true,
          selected: isSelected,
          enabled: true,
          focusable: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with subtle background indicator
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected && tab.activeIcon != null
                        ? tab.activeIcon!
                        : tab.icon,
                    size: 18,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),

                const SizedBox(height: 2),

                // Label with custom styling
                Text(
                  tab.label,
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
