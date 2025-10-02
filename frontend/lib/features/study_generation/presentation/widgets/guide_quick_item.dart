import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../saved_guides/domain/entities/saved_guide_entity.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Compact guide list item for the recent studies section
///
/// Features:
/// - Compact horizontal layout
/// - Title with overflow handling
/// - Type indicator (Scripture vs Topic)
/// - Timestamp display
/// - Save/unsave action (optional)
class GuideQuickItem extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool showSaveAction;

  const GuideQuickItem({
    super.key,
    required this.guide,
    required this.onTap,
    this.onSave,
    this.showSaveAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Type indicator icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    guide.type == GuideType.verse
                        ? Icons.book_outlined
                        : Icons.lightbulb_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 12),

                // Content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        guide.displayTitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Subtitle (reference or type)
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getTimeAgo(context, guide.lastAccessedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action button (save/unsave)
                if (showSaveAction && onSave != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onSave,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        guide.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 16,
                        color: guide.isSaved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(BuildContext context, DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return context.tr(TranslationKeys.recentGuidesDaysAgo,
          {'count': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return context.tr(TranslationKeys.recentGuidesHoursAgo,
          {'count': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return context.tr(TranslationKeys.recentGuidesMinutesAgo,
          {'count': difference.inMinutes.toString()});
    } else {
      return context.tr(TranslationKeys.recentGuidesJustNow);
    }
  }
}
