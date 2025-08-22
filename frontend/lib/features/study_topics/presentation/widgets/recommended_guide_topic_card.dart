import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';

/// Reusable card widget for displaying recommended guide topics.
///
/// This widget provides consistent visual styling and behavior across
/// the Home screen and Study Topics screen.
class RecommendedGuideTopicCard extends StatelessWidget {
  final RecommendedGuideTopic topic;
  final VoidCallback onTap;

  const RecommendedGuideTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForCategory(topic.category);
    final color = _getColorForCategory(topic.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180, // Fixed height for uniform cards
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min, // Important: Don't expand unnecessarily
          children: [
            // Header row with icon
            Row(
              children: [
                Container(
                  width: 36, // Slightly smaller for better proportions
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    iconData,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8), // Fixed spacing instead of Spacer
                Flexible(
                  // Use Flexible instead of Spacer
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      topic.category,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title with proper constraints
            Text(
              topic.title,
              style: GoogleFonts.inter(
                fontSize: 14, // Slightly smaller for better fit
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2, // Tighter line height
              ),
              maxLines: 2, // Allow 2 lines for longer titles
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6), // Reduced spacing

            // Description with flexible height
            Flexible(
              child: Text(
                topic.description,
                style: GoogleFonts.inter(
                  fontSize: 11, // Smaller font for more content
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.3,
                ),
                maxLines: 3, // Allow up to 3 lines
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12), // Fixed spacing instead of Spacer

            // Footer with metadata - commented out for now as entity doesn't have these fields
            // Row(
            //   children: [
            //     Icon(
            //       Icons.schedule,
            //       size: 12,
            //       color: AppTheme.onSurfaceVariant,
            //     ),
            //     const SizedBox(width: 3),
            //     Text(
            //       '${topic.estimatedMinutes}min',
            //       style: GoogleFonts.inter(
            //         fontSize: 10,
            //         color: AppTheme.onSurfaceVariant,
            //       ),
            //     ),
            //     const SizedBox(width: 12),
            //     Icon(
            //       Icons.book_outlined,
            //       size: 12,
            //       color: AppTheme.onSurfaceVariant,
            //     ),
            //     const SizedBox(width: 3),
            //     Text(
            //       '${topic.scriptureCount}',
            //       style: GoogleFonts.inter(
            //         fontSize: 10,
            //         color: AppTheme.onSurfaceVariant,
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  // Category to icon mapping
  static const Map<String, IconData> _categoryIcons = {
    'apologetics & defense of faith': Icons.shield,
    'christian life': Icons.directions_walk,
    'church & community': Icons.groups,
    'discipleship & growth': Icons.trending_up,
    'family & relationships': Icons.family_restroom,
    'foundations of faith': Icons.foundation,
    'mission & service': Icons.volunteer_activism,
    'spiritual disciplines': Icons.self_improvement,
  };

  // Category to color mapping
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

  IconData _getIconForCategory(String category) =>
      _categoryIcons[category.toLowerCase()] ?? Icons.menu_book;

  Color _getColorForCategory(String category) =>
      _categoryColors[category.toLowerCase()] ?? AppTheme.primaryColor;
}
