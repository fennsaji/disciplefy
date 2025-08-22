import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Horizontal scrollable chips for category filtering with multi-select capability.
class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;
  final bool isLoading;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedCategories,
    required this.onCategoriesChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingChips(context: context);
    }

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filter by Category',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              if (selectedCategories.isNotEmpty)
                TextButton(
                  onPressed: () => onCategoriesChanged([]),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1, // +1 for "All" chip
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "All" chip
                  final isSelected = selectedCategories.isEmpty;
                  return _buildChip(
                    context: context,
                    label: 'All',
                    isSelected: isSelected,
                    onTap: () => onCategoriesChanged([]),
                    icon: Icons.all_inclusive_rounded,
                    originalCategory: 'All',
                  );
                }

                final category = categories[index - 1];
                final isSelected = selectedCategories.contains(category);

                return _buildChip(
                  context: context,
                  label: _formatCategoryName(category),
                  isSelected: isSelected,
                  onTap: () => _toggleCategory(category),
                  icon: _getCategoryIcon(category),
                  originalCategory: category,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
    IconData? icon,
    String? originalCategory,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500, // Bolder when selected
                color: isSelected
                    ? Colors.white
                    : Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.5),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 0, // Higher elevation for selected chips
        pressElevation: 6,
        shadowColor: isSelected ? AppTheme.primaryColor.withOpacity(0.3) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(
                    0.3), // Slightly more visible border for unselected
            width: isSelected ? 2 : 1, // Thicker border for selected chips
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildLoadingChips({
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Category',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5, // Show 5 loading chips
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    height: 32,
                    width: 80 + (index * 10), // Varying widths
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCategory(String category) {
    final newSelection = List<String>.from(selectedCategories);

    if (newSelection.contains(category)) {
      newSelection.remove(category);
    } else {
      newSelection.add(category);
    }

    onCategoriesChanged(newSelection);
  }

  /// Format category name for display (capitalize each word)
  String _formatCategoryName(String category) {
    return category
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Get relevant icon for each category
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'foundations of faith':
        return Icons.foundation_rounded; // Foundation/base icon
      case 'spiritual disciplines':
        return Icons.self_improvement_rounded; // Meditation/spiritual growth
      case 'christian life':
        return Icons.menu_book_rounded; // Book for learning
      case 'church & community':
        return Icons.groups_rounded; // Community/people icon
      case 'family & relationships':
        return Icons.family_restroom_rounded; // Family icon
      case 'discipleship & growth':
        return Icons.trending_up_rounded; // Growth/progress icon
      case 'mission & service':
        return Icons.volunteer_activism_rounded; // Service/helping hands
      case 'apologetics & defense of faith':
        return Icons.shield_rounded; // Shield for defense
      default:
        return Icons.category_rounded; // Default category icon
    }
  }
}
