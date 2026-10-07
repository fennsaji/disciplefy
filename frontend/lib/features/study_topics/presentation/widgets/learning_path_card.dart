import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_level_style.dart';

/// Localised name of a disciple level (`seeker`, `follower`, ...).
String discipleLevelLabel(BuildContext context, String level) {
  switch (level.toLowerCase()) {
    case 'seeker':
      return context.tr(TranslationKeys.discipleLevelSeeker);
    case 'believer':
      return context.tr(TranslationKeys.discipleLevelBeliever);
    case 'disciple':
      return context.tr(TranslationKeys.discipleLevelDisciple);
    case 'leader':
      return context.tr(TranslationKeys.discipleLevelLeader);
    case 'follower':
      return context.tr(TranslationKeys.discipleLevelFollower);
    default:
      return level.isEmpty
          ? level
          : level[0].toUpperCase() + level.substring(1);
  }
}

/// Gradient tile for a learning path (For you row, category rows).
///
/// Coloured by the path's disciple level ([PathLevelStyle]), with the path
/// icon drawn large and faint in the top-right corner. Shows the status
/// (completed / in progress / featured), level and topic count, title, XP,
/// duration and — once enrolled — progress.
class LearningPathCard extends StatelessWidget {
  /// The learning path data.
  final LearningPath path;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  /// Fixed tile width for horizontal rows; `false` fills the parent width.
  final bool compact;

  /// Keep room for the progress bar even when this path has none, so tiles
  /// in a row where some show progress all have the same height.
  final bool reserveProgressSpace;

  /// Tile width when [compact].
  static const double compactWidth = 200;

  /// Minimum tile height.
  static const double minHeight = 150;

  const LearningPathCard({
    super.key,
    required this.path,
    required this.onTap,
    this.compact = true,
    this.reserveProgressSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    final topicsLabel = context.tr(TranslationKeys.learningPathsTopics);
    final topics = path.isEnrolled
        ? '${path.topicsCompleted}/${path.topicsCount} $topicsLabel'
        : '${path.topicsCount} $topicsLabel';
    final eyebrow =
        '${discipleLevelLabel(context, path.discipleLevel)} · $topics'
            .toUpperCase();

    final tile = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Stack(
        children: [
          Positioned.fill(
            child:
                PathLevelStyle.background(path.discipleLevel, radius: radius),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: ExcludeSemantics(
              child: Icon(
                iconForPath(path.iconName, category: path.category),
                size: 52,
                color: PathLevelStyle.motifColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status badge, or empty room for the icon motif.
                Padding(
                  padding: const EdgeInsets.only(right: 60),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 26),
                    child: Align(
                      alignment: Alignment.topLeft,
                      // A path closed to the guest shows its lock first, on
                      // the left, so it is visible even when the tile is only
                      // partly scrolled into a row.
                      child: ValueListenableBuilder<String?>(
                        valueListenable: GuestPathEnrollment.changes,
                        builder: (context, _, __) => isGuestLockedPath(path)
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GuestPathLockBadge(path: path),
                                  const SizedBox(width: 6),
                                  Flexible(child: _StatusBadge(path: path)),
                                ],
                              )
                            : _StatusBadge(path: path),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  eyebrow,
                  maxLines: 2,
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: PathLevelStyle.eyebrowGold,
                  ),
                ),
                const SizedBox(height: 4),
                // Room for two lines, so tiles in a row line up unless a
                // title needs a third.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.textScalerOf(context).scale(16) * 1.25 * 2,
                  ),
                  child: Text(
                    path.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MetaRow(path: path),
                if (path.isEnrolled || reserveProgressSpace) ...[
                  const SizedBox(height: 10),
                  Visibility(
                    visible: path.isEnrolled,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: _TileProgress(path: path),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      child: SizedBox(
        width: compact ? compactWidth : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: tile,
          ),
        ),
      ),
    );
  }
}

/// XP and duration, wrapping instead of truncating.
class _MetaRow extends StatelessWidget {
  final LearningPath path;

  const _MetaRow({required this.path});

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.85),
    );
    final iconColor = Colors.white.withValues(alpha: 0.8);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              path.isCompleted
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 15,
              color: path.isCompleted ? PathLevelStyle.eyebrowGold : iconColor,
            ),
            const SizedBox(width: 4),
            Text(
                '${path.totalXp} ${context.tr(TranslationKeys.learningPathsXp)}',
                style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              '${path.estimatedDays} ${context.tr(TranslationKeys.learningPathsDays)}',
              style: style,
            ),
          ],
        ),
      ],
    );
  }
}

/// Thin gold progress bar with the percentage.
class _TileProgress extends StatelessWidget {
  final LearningPath path;

  const _TileProgress({required this.path});

  @override
  Widget build(BuildContext context) {
    final value = (path.progressPercentage / 100).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor:
                  const AlwaysStoppedAnimation(PathLevelStyle.eyebrowGold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${path.progressPercentage}%',
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: PathLevelStyle.eyebrowGold,
          ),
        ),
      ],
    );
  }
}

/// Completed / in progress / featured pill on a dark glass chip.
class _StatusBadge extends StatelessWidget {
  final LearningPath path;

  const _StatusBadge({required this.path});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (path.isCompleted) {
      icon = Icons.check_circle_rounded;
      label = context.tr(TranslationKeys.learningPathsCompleted);
    } else if (path.isInProgress) {
      icon = Icons.play_circle_fill_rounded;
      label = context.tr(TranslationKeys.learningPathsInProgress);
    } else if (path.isFeatured) {
      icon = Icons.auto_awesome_rounded;
      label = context.tr(TranslationKeys.learningPathsFeatured);
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: PathLevelStyle.eyebrowGold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a [LearningPathCard] while paths load.
class LearningPathCardSkeleton extends StatelessWidget {
  final bool compact;

  const LearningPathCardSkeleton({
    super.key,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: compact ? LearningPathCard.compactWidth : null,
      height: LearningPathCard.minHeight,
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
