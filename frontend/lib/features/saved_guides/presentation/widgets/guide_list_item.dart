import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/saved_guide_entity.dart';

class GuideListItem extends StatelessWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool showRemoveOption;

  const GuideListItem({
    super.key,
    required this.guide,
    required this.onTap,
    this.onRemove,
    this.showRemoveOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: AppTheme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: showRemoveOption ? onRemove : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
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
                            color: AppTheme.textPrimary,
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
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showRemoveOption && onRemove != null)
                    PopupMenuButton<String>(
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
                              Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('Remove'),
                            ],
                          ),
                        ),
                      ],
                      child: Icon(
                        Icons.more_vert,
                        color: AppTheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildContentPreview(),
              const SizedBox(height: 12),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

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
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildContentPreview() {
    final preview = guide.content.length > 100 
        ? '${guide.content.substring(0, 100)}...'
        : guide.content;

    return Text(
      preview,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppTheme.textPrimary,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter() {
    final timeFormat = DateFormat('MMM d, yyyy • h:mm a');
    final timeText = timeFormat.format(guide.lastAccessedAt);

    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: AppTheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (guide.type == GuideType.verse && guide.verseReference != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Verse',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          )
        else if (guide.type == GuideType.topic && guide.topicName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
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
      ],
    );
  }
}