import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared utility class for study topic category colors and icons.
/// Centralizes category-specific styling to ensure consistency across the app.
class CategoryUtils {
  /// Category color mappings
  static const Map<String, Color> _categoryColors = {
    'apologetics & defense of faith': Color(0xFF1565C0), // Deep Blue
    'christian life': Color(0xFF2E7D32), // Green
    'church & community': Color(0xFFE65100), // Orange
    'discipleship & growth': Color(0xFF7B1FA2), // Purple
    'family & relationships': Color(0xFFD32F2F), // Red
    'foundations of faith': Color(0xFF5D4037), // Brown
    'mission & service': Color(0xFF455A64), // Blue Grey
    'spiritual disciplines': Color(0xFF00695C), // Teal
  };

  /// Category icon mappings
  static const Map<String, IconData> _categoryIcons = {
    'apologetics & defense of faith': Icons.shield_rounded,
    'christian life': Icons.menu_book_rounded,
    'church & community': Icons.groups_rounded,
    'discipleship & growth': Icons.trending_up_rounded,
    'family & relationships': Icons.family_restroom_rounded,
    'foundations of faith': Icons.foundation_rounded,
    'mission & service': Icons.volunteer_activism_rounded,
    'spiritual disciplines': Icons.self_improvement_rounded,
  };

  /// Get color for a specific category with theme awareness
  static Color getColorForCategory(BuildContext context, String category) {
    final baseColor =
        _categoryColors[category.toLowerCase()] ?? AppTheme.primaryColor;

    // Use lighter variant for dark theme
    if (Theme.of(context).brightness == Brightness.dark) {
      return Color.lerp(baseColor, Colors.white, 0.6) ?? baseColor;
    }

    return baseColor;
  }

  /// Get icon for a specific category
  static IconData getIconForCategory(String category) {
    return _categoryIcons[category.toLowerCase()] ?? Icons.category_rounded;
  }

  /// Format category name for display (capitalize each word)
  static String formatCategoryName(String category) {
    return category
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Get all available categories
  static List<String> get availableCategories => _categoryColors.keys.toList();
}
