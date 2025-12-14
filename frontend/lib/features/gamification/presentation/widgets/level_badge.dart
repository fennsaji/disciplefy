import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_level.dart';

/// Small badge showing user level
class LevelBadge extends StatelessWidget {
  final UserLevel level;
  final LevelBadgeSize size;
  final bool showTitle;

  const LevelBadge({
    super.key,
    required this.level,
    this.size = LevelBadgeSize.medium,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimensions = _getDimensions();

    if (showTitle) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(dimensions),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level ${level.level}',
                style: AppFonts.inter(
                  fontSize: dimensions.titleFontSize,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                level.title,
                style: AppFonts.poppins(
                  fontSize: dimensions.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _buildBadge(dimensions);
  }

  Widget _buildBadge(_BadgeDimensions dimensions) {
    return Container(
      width: dimensions.size,
      height: dimensions.size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: dimensions.shadowBlur,
            offset: Offset(0, dimensions.shadowOffset),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${level.level}',
          style: AppFonts.poppins(
            fontSize: dimensions.fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  _BadgeDimensions _getDimensions() {
    switch (size) {
      case LevelBadgeSize.small:
        return const _BadgeDimensions(
          size: 24,
          fontSize: 11,
          shadowBlur: 4,
          shadowOffset: 2,
          titleFontSize: 10,
          subtitleFontSize: 12,
        );
      case LevelBadgeSize.medium:
        return const _BadgeDimensions(
          size: 36,
          fontSize: 14,
          shadowBlur: 6,
          shadowOffset: 3,
          titleFontSize: 11,
          subtitleFontSize: 14,
        );
      case LevelBadgeSize.large:
        return const _BadgeDimensions(
          size: 48,
          fontSize: 18,
          shadowBlur: 8,
          shadowOffset: 4,
          titleFontSize: 12,
          subtitleFontSize: 16,
        );
      case LevelBadgeSize.extraLarge:
        return const _BadgeDimensions(
          size: 64,
          fontSize: 24,
          shadowBlur: 12,
          shadowOffset: 6,
          titleFontSize: 14,
          subtitleFontSize: 18,
        );
    }
  }
}

enum LevelBadgeSize { small, medium, large, extraLarge }

class _BadgeDimensions {
  final double size;
  final double fontSize;
  final double shadowBlur;
  final double shadowOffset;
  final double titleFontSize;
  final double subtitleFontSize;

  const _BadgeDimensions({
    required this.size,
    required this.fontSize,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.titleFontSize,
    required this.subtitleFontSize,
  });
}
