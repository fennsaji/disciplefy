import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/home/domain/entities/recommended_guide_topic.dart';

/// Shared utility class for study topic category colors and icons.
/// Centralizes category-specific styling to ensure consistency across the app.
class CategoryUtils {
  /// Mapping from translated category names to English keys for styling
  static const Map<String, String> _translatedToEnglish = {
    // Hindi translations
    'विश्वास की नींव': 'foundations of faith',
    'मसीही जीवन': 'christian life',
    'कलीसिया और समुदाय': 'church & community',
    'शिष्यत्व और विकास': 'discipleship & growth',
    'आत्मिक अनुशासन': 'spiritual disciplines',
    'धर्मशास्त्र और विश्वास की रक्षा': 'apologetics & defense of faith',
    'परिवार और रिश्ते': 'family & relationships',
    'मिशन और सेवा': 'mission & service',

    // Malayalam translations
    'വിശ്വാസത്തിന്റെ അടിത്തറകൾ': 'foundations of faith',
    'ക്രൈസ്തവ ജീവിതം': 'christian life',
    'സഭയും സമൂഹവും': 'church & community',
    'ശിഷ്യത്വവും വളർച്ചയും': 'discipleship & growth',
    'ആത്മീയ അനുശാസനം': 'spiritual disciplines',
    'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും': 'apologetics & defense of faith',
    'കുടുംബവും ബന്ധങ്ങളും': 'family & relationships',
    'മിഷനും സേവനവും': 'mission & service',

    // English categories (passthrough)
    'foundations of faith': 'foundations of faith',
    'christian life': 'christian life',
    'church & community': 'church & community',
    'discipleship & growth': 'discipleship & growth',
    'spiritual disciplines': 'spiritual disciplines',
    'apologetics & defense of faith': 'apologetics & defense of faith',
    'family & relationships': 'family & relationships',
    'mission & service': 'mission & service',
  };

  /// Category color mappings
  static const Map<String, Color> _categoryColors = {
    'apologetics & defense of faith': AppColors.categoryApologetics,
    'christian life': AppColors.categoryChristianLife,
    'church & community': AppColors.categoryChurch,
    'discipleship & growth': AppColors.categoryDiscipleship,
    'family & relationships': AppColors.categoryFamily,
    'foundations of faith': AppColors.categoryFoundations,
    'mission & service': AppColors.categoryMission,
    'spiritual disciplines': AppColors.categorySpiritualDisciplines,
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
  /// Uses the English category name for consistent styling across languages
  static Color getColorForCategory(BuildContext context, String category) {
    final englishCategory = _translatedToEnglish[category] ?? category;
    final normalized = englishCategory.trim().toLowerCase();
    final baseColor = _categoryColors[normalized] ?? AppTheme.primaryColor;

    // Use lighter variant for dark theme
    if (Theme.of(context).brightness == Brightness.dark) {
      return Color.lerp(baseColor, Colors.white, 0.6) ?? baseColor;
    }

    return baseColor;
  }

  /// Get color for a recommended topic using its English category
  /// This ensures consistent styling across all languages
  static Color getColorForTopic(
      BuildContext context, RecommendedGuideTopic topic) {
    return getColorForCategory(context, topic.categoryForStyling);
  }

  /// Get icon for a specific category
  static IconData getIconForCategory(String category) {
    final englishCategory = _translatedToEnglish[category] ?? category;
    final normalized = englishCategory.trim().toLowerCase();
    return _categoryIcons[normalized] ?? Icons.category_rounded;
  }

  /// Get icon for a recommended topic using its English category
  /// This ensures consistent icons across all languages
  static IconData getIconForTopic(RecommendedGuideTopic topic) {
    return getIconForCategory(topic.categoryForStyling);
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
