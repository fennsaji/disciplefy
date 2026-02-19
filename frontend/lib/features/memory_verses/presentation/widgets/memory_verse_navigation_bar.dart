import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/router/app_routes.dart';

/// Horizontal Navigation Bar for Memory Verses Features.
///
/// Provides quick access to:
/// - Champions Leaderboard
/// - Statistics & Heat Map
class MemoryVerseNavigationBar extends StatelessWidget {
  const MemoryVerseNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationItems = [
      _NavigationItem(
        icon: Icons.emoji_events_outlined,
        label: context.tr(TranslationKeys.champions),
        route: AppRoutes.memoryChampions,
        color: AppColors.masteryMaster,
      ),
      _NavigationItem(
        icon: Icons.bar_chart,
        label: context.tr(TranslationKeys.statistics),
        route: AppRoutes.memoryStats,
        color: AppColors.success,
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: navigationItems.length,
        itemBuilder: (context, index) {
          final item = navigationItems[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < navigationItems.length - 1 ? 12 : 0,
            ),
            child: _NavigationCard(
              item: item,
              onTap: () => context.push(item.route),
            ),
          );
        },
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  _NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

class _NavigationCard extends StatelessWidget {
  final _NavigationItem item;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : AppColors.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? item.color.withOpacity(0.15)
                    : item.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: isDark ? item.color.withOpacity(0.9) : item.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
