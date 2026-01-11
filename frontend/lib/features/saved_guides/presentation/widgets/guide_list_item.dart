import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/animations/app_animations.dart';
import '../../domain/entities/saved_guide_entity.dart';

/// Unified Guide List Item with save/unsave functionality and tap animation
class GuideListItem extends StatefulWidget {
  final SavedGuideEntity guide;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onSave;
  final bool showRemoveOption;
  final bool isLoading;

  const GuideListItem({
    super.key,
    required this.guide,
    required this.onTap,
    this.onRemove,
    this.onSave,
    this.showRemoveOption = false,
    this.isLoading = false,
  });

  @override
  State<GuideListItem> createState() => _GuideListItemState();
}

class _GuideListItemState extends State<GuideListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (!widget.isLoading) {
      widget.onTap();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            color: Theme.of(context).colorScheme.surface,
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildIcon(context),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.guide.displayTitle,
                                  style: AppFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isLoading
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.guide.subtitle,
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                if (widget.isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildIcon(BuildContext context) {
    IconData iconData;
    Color iconColor;

    if (widget.guide.isSaved) {
      iconData = Icons.bookmark;
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      iconData =
          widget.guide.type == GuideType.verse ? Icons.menu_book : Icons.topic;
      iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
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
    if (widget.showRemoveOption && widget.onRemove != null) {
      // Show remove options for saved guides
      return PopupMenuButton<String>(
        enabled: !widget.isLoading,
        onSelected: (value) {
          if (value == 'remove') {
            widget.onRemove!();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.bookmark_remove,
                    color: Theme.of(context).colorScheme.error),
                SizedBox(width: 8),
                Text('Remove from Saved'),
              ],
            ),
          ),
        ],
        child: Icon(
          Icons.more_vert,
          color: widget.isLoading
              ? Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      );
    } else if (widget.onSave != null && !widget.guide.isSaved) {
      // Show save button for recent guides that aren't saved
      return IconButton(
        onPressed: widget.isLoading ? null : widget.onSave,
        icon: Icon(
          Icons.bookmark_border,
          color: widget.isLoading
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        tooltip: 'Save Guide',
        splashRadius: 20,
      );
    } else if (widget.guide.isSaved) {
      // Show filled bookmark for already saved guides
      return Icon(
        Icons.bookmark,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      );
    }

    return const SizedBox(width: 20);
  }

  Widget _buildContentPreview(BuildContext context) => Text(
        widget.guide.contentPreview,
        style: AppFonts.inter(
          fontSize: 14,
          color: widget.isLoading
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
              : Theme.of(context).colorScheme.onSurface,
          height: 1.4,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );

  Widget _buildFooter(BuildContext context) {
    final timeFormat = DateFormat('MMM d, yyyy');
    final timeText = timeFormat.format(widget.guide.lastAccessedAt);

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
          style: AppFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            if (widget.guide.type == GuideType.verse &&
                widget.guide.verseReference != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Scripture',
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            else if (widget.guide.type == GuideType.topic)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Topic',
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            if (widget.guide.studyModeDisplay != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.guide.studyModeDisplay!,
                      style: AppFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                    if (widget.guide.studyModeDuration != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '• ${widget.guide.studyModeDuration}',
                        style: AppFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.successColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            if (widget.guide.isSaved)
              Icon(
                Icons.bookmark,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ],
    );
  }
}
