import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/utils/category_utils.dart';

/// Explicit map of Material icon names stored in `learning_paths.icon_name`
/// to their [IconData].
///
/// Flutter cannot resolve an icon from its name at runtime, so every name
/// used by a learning path must be listed here.
const Map<String, IconData> _pathIcons = {
  'account_balance': Icons.account_balance_rounded,
  'air': Icons.air_rounded,
  'anchor': Icons.anchor_rounded,
  'auto_awesome': Icons.auto_awesome_rounded,
  'auto_stories': Icons.auto_stories_rounded,
  'book': Icons.book_rounded,
  'brightness_5': Icons.brightness_5_rounded,
  'church': Icons.church_rounded,
  'diversity_3': Icons.diversity_3_rounded,
  'explore': Icons.explore_rounded,
  'family_restroom': Icons.family_restroom_rounded,
  'favorite': Icons.favorite_rounded,
  'front_hand': Icons.front_hand_rounded,
  'gavel': Icons.gavel_rounded,
  'gpp_bad': Icons.gpp_bad_rounded,
  'group': Icons.group_rounded,
  'groups': Icons.groups_rounded,
  'healing': Icons.healing_rounded,
  'help_outline': Icons.help_outline_rounded,
  'history_edu': Icons.history_edu_rounded,
  'import_contacts': Icons.import_contacts_rounded,
  'language': Icons.language_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'lock_open': Icons.lock_open_rounded,
  'menu_book': Icons.menu_book_rounded,
  'military_tech': Icons.military_tech_rounded,
  'park': Icons.park_rounded,
  'people': Icons.people_rounded,
  'psychology': Icons.psychology_rounded,
  'public': Icons.public_rounded,
  'record_voice_over': Icons.record_voice_over_rounded,
  'restart_alt': Icons.restart_alt_rounded,
  'school': Icons.school_rounded,
  'self_improvement': Icons.self_improvement_rounded,
  'sentiment_very_satisfied': Icons.sentiment_very_satisfied_rounded,
  'shield': Icons.shield_rounded,
  'spa': Icons.spa_rounded,
  'star': Icons.star_rounded,
  'terrain': Icons.terrain_rounded,
  'trending_up': Icons.trending_up_rounded,
  'verified': Icons.verified_rounded,
  'visibility': Icons.visibility_rounded,
  'volunteer_activism': Icons.volunteer_activism_rounded,
  'water_drop': Icons.water_drop_rounded,
  'wb_sunny': Icons.wb_sunny_rounded,
  'work': Icons.work_rounded,
  'workspace_premium': Icons.workspace_premium_rounded,
};

/// Default icon for a learning path with no recognisable icon or category.
const IconData defaultPathIcon = Icons.auto_stories_rounded;

/// Returns the icon for a learning path.
///
/// Resolves [iconName] (a Material icon name such as `auto_stories`) first.
/// When it is missing or unknown, falls back to the [category] icon if that
/// category has a specific one, and finally to [defaultPathIcon].
IconData iconForPath(String? iconName, {String? category}) {
  final key = iconName?.trim().toLowerCase();
  if (key != null && key.isNotEmpty) {
    final icon = _pathIcons[key] ??
        _pathIcons[key.replaceAll(RegExp(r'_(rounded|outlined|sharp)$'), '')];
    if (icon != null) return icon;
  }
  if (category != null && category.trim().isNotEmpty) {
    final categoryIcon = CategoryUtils.getIconForCategory(category);
    if (categoryIcon != Icons.category_rounded) return categoryIcon;
  }
  return defaultPathIcon;
}
