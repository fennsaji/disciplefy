import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/saved_guide_entity.dart';

/// Enhanced Guide List Item with API save/unsave functionality
class GuideListItemApi extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onSave;
  final bool showRemoveOption;
  final bool isLoading;

  const GuideListItemApi({
    super.key,
    required this.guide,
    required this.onTap,
    this.onRemove,
    this.onSave,
    this.showRemoveOption = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.displayTitle,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isLoading 
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                    : Theme.of(context).colorScheme.onSurface,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guide.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildActionButton(context),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildContentPreview(context),
                  const SizedBox(height: 12),
                  _buildFooter(context),
                ],
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor;

    if (guide.isSaved) {
      iconData = Icons.bookmark;
      iconColor = AppTheme.primaryColor;
    } else {
      iconData = guide.type == GuideType.verse 
          ? Icons.menu_book 
          : Icons.topic;
      iconColor = AppTheme.onSurfaceVariant;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (showRemoveOption && onRemove != null) {
      // Show remove options for saved guides
      return PopupMenuButton<String>(
        enabled: !isLoading,
        onSelected: (value) {
          if (value == 'remove') {
            onRemove!();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.bookmark_remove, color: AppTheme.errorColor),
                SizedBox(width: 8),
                Text('Remove from Saved'),
              ],
            ),
          ),
        ],
        child: Icon(
          Icons.more_vert,
          color: isLoading 
              ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      );
    } else if (onSave != null && !guide.isSaved) {
      // Show save button for recent guides that aren't saved
      return IconButton(
        onPressed: isLoading ? null : onSave,
        icon: Icon(
          Icons.bookmark_border,
          color: isLoading 
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.primaryColor,
          size: 20,
        ),
        tooltip: 'Save Guide',
        splashRadius: 20,
      );
    } else if (guide.isSaved) {
      // Show filled bookmark for already saved guides
      return const Icon(
        Icons.bookmark,
        color: AppTheme.primaryColor,
        size: 20,
      );
    }

    return const SizedBox(width: 20);
  }

  Widget _buildContentPreview(BuildContext context) {
    String preview;
    
    // Extract meaningful content from the formatted content
    if (guide.content.contains('**Summary:**')) {
      final summaryMatch = RegExp(r'\*\*Summary:\*\*\n(.*?)(?:\n\*\*|\n?$)', dotAll: true)
          .firstMatch(guide.content);
      if (summaryMatch != null) {
        preview = summaryMatch.group(1)?.trim() ?? guide.content;
      } else {
        preview = guide.content;
      }
    } else {
      preview = guide.content;
    }

    // Limit preview length
    if (preview.length > 120) {
      preview = '${preview.substring(0, 120)}...';
    }

    return Text(
      preview,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: isLoading 
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
            : Theme.of(context).colorScheme.onSurface,
        height: 1.4,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final timeFormat = DateFormat('MMM d, yyyy');
    final timeText = timeFormat.format(guide.lastAccessedAt);

    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            if (guide.type == GuideType.verse && guide.verseReference != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Scripture',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else if (guide.type == GuideType.topic)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Topic',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            if (guide.isSaved)
              const Icon(
                Icons.bookmark,
                size: 16,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ],
    );
  }
}