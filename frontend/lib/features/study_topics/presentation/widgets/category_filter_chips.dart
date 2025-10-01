import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

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

    return _CategoryFilterSection(
      categories: categories,
      selectedCategories: selectedCategories,
      onClearAll: () => onCategoriesChanged([]),
      onToggleCategory: _toggleCategory,
      onSelectAll: () => onCategoriesChanged([]),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
    IconData? icon,
    String? category,
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
                color: isSelected
                    ? Colors.white
                    : category != null
                        ? CategoryUtils.getColorForCategory(context, category)
                        : AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
                    color: isSelected
                        ? Colors.white
                        : category != null
                            ? CategoryUtils.getColorForCategory(
                                context, category)
                            : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: category != null
            ? CategoryUtils.getColorForCategory(context, category)
            : AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 0, // Higher elevation for selected chips
        pressElevation: 6,
        shadowColor: isSelected
            ? (category != null
                ? CategoryUtils.getColorForCategory(context, category)
                    .withOpacity(0.3)
                : AppTheme.primaryColor.withOpacity(0.3))
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? (category != null
                    ? CategoryUtils.getColorForCategory(context, category)
                    : AppTheme.primaryColor)
                : (category != null
                        ? CategoryUtils.getColorForCategory(context, category)
                        : AppTheme.primaryColor)
                    .withOpacity(0.3),
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
            context.tr(TranslationKeys.categoryFilterTitle),
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
}

/// Category filter section with header and horizontal scrollable chips.
class _CategoryFilterSection extends StatelessWidget {
  final List<String> categories;
  final List<String> selectedCategories;
  final VoidCallback onClearAll;
  final Function(String) onToggleCategory;
  final VoidCallback onSelectAll;

  const _CategoryFilterSection({
    required this.categories,
    required this.selectedCategories,
    required this.onClearAll,
    required this.onToggleCategory,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
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
          _Header(
            selectedCategories: selectedCategories,
            onClearAll: onClearAll,
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
                    label: context.tr(TranslationKeys.categoryFilterAll),
                    isSelected: isSelected,
                    onTap: onSelectAll,
                    icon: Icons.all_inclusive_rounded,
                  );
                }

                final category = categories[index - 1];
                final isSelected = selectedCategories.contains(category);

                return _buildChip(
                  context: context,
                  label: CategoryUtils.formatCategoryName(category),
                  isSelected: isSelected,
                  onTap: () => onToggleCategory(category),
                  icon: CategoryUtils.getIconForCategory(category),
                  category: category,
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
    String? category,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : category != null
                          ? CategoryUtils.getColorForCategory(context, category)
                          : AppTheme.primaryColor),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
                    color: isSelected
                        ? Colors.white
                        : category != null
                            ? CategoryUtils.getColorForCategory(
                                context, category)
                            : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: category != null
            ? CategoryUtils.getColorForCategory(context, category)
            : AppTheme.primaryColor,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 0, // Higher elevation for selected chips
        pressElevation: 6,
        shadowColor: isSelected
            ? (category != null
                ? CategoryUtils.getColorForCategory(context, category)
                    .withOpacity(0.3)
                : AppTheme.primaryColor.withOpacity(0.3))
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? (category != null
                    ? CategoryUtils.getColorForCategory(context, category)
                    : AppTheme.primaryColor)
                : (category != null
                        ? CategoryUtils.getColorForCategory(context, category)
                        : AppTheme.primaryColor)
                    .withOpacity(0.3),
            width: isSelected ? 2 : 1, // Thicker border for selected chips
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Header widget with title and clear all button.
class _Header extends StatelessWidget {
  final List<String> selectedCategories;
  final VoidCallback onClearAll;

  const _Header({
    required this.selectedCategories,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.tr(TranslationKeys.categoryFilterTitle),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const Spacer(),
        if (selectedCategories.isNotEmpty)
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              context.tr(TranslationKeys.categoryFilterClearAll),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
