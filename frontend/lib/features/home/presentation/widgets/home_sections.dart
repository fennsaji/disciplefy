import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../study_topics/domain/entities/learning_path.dart';

/// Colours for the cards under the home hero, per theme: white cards with a
/// warm hairline on light, raised near-black cards on dark.
class _HomeCardColors {
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color ringTrack;
  final Color chevron;
  final Color link;

  const _HomeCardColors({
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.ringTrack,
    required this.chevron,
    required this.link,
  });

  factory _HomeCardColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const _HomeCardColors(
            surface: Color(0xFF17171C),
            border: Color(0x0DFFFFFF),
            textPrimary: Color(0xFFF2F2F4),
            textMuted: Color(0xFF9CA3AF),
            ringTrack: Color(0xFF26262F),
            chevron: Color(0xFF5A5A63),
            link: Color(0xFF9CA3AF),
          )
        : const _HomeCardColors(
            surface: Colors.white,
            border: Color(0xFFE9E5DB),
            textPrimary: Color(0xFF1A1917),
            textMuted: Color(0xFF6F6B61),
            ringTrack: Color(0xFFEEEBE3),
            chevron: Color(0xFFB5B0A4),
            link: AppColors.brandPrimary,
          );
  }
}

BoxDecoration _cardDecoration(_HomeCardColors c, double radius) =>
    BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.border),
    );

/// Section heading used by every block under the hero: a title, an optional
/// subtitle and an optional trailing text action.
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = _HomeCardColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppFonts.inter(fontSize: 12, color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.link,
              ),
            ),
          ),
      ],
    );
  }
}

/// One of the two small tiles under the hero (streak, verses to review).
class HomeStatTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  /// Shown after [subtitle] and never cut: when the line is too long the
  /// subtitle shortens instead (e.g. a long reference before "+2 more").
  final String? subtitleSuffix;
  final VoidCallback? onTap;

  const HomeStatTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.subtitleSuffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = _HomeCardColors.of(context);
    return Semantics(
      button: onTap != null,
      label:
          '$title, $subtitle${subtitleSuffix == null ? '' : ' $subtitleSuffix'}',
      excludeSemantics: true,
      child: HomePressable(
          builder: (onHighlight) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  onHighlightChanged: onHighlight,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: _cardDecoration(c, 16),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 17, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Wraps rather than cuts: the reference and "+N more"
                              // flow onto a second line when the tile is slim.
                              Text.rich(
                                TextSpan(
                                  text: subtitle,
                                  children: [
                                    if (subtitleSuffix != null)
                                      TextSpan(
                                        text: '  $subtitleSuffix',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.inter(
                                  fontSize: 12,
                                  color: c.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
    );
  }
}

/// Content width below which the streak and review tiles stack.
const double homeTilesStackBelowWidth = 330;

/// Streak and review tiles side by side. The review tile is dropped when the
/// memory-verses feature is hidden for the user's plan; the streak tile then
/// takes the full row.
class HomeTodayTiles extends StatelessWidget {
  final int streakDays;
  final int dueCount;
  final bool showReview;
  final String? nextReviewReference;
  final VoidCallback? onStreakTap;
  final VoidCallback? onReviewTap;

  const HomeTodayTiles({
    super.key,
    required this.streakDays,
    required this.dueCount,
    required this.showReview,
    this.nextReviewReference,
    this.onStreakTap,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gold = dark ? AppColors.brandGold : AppColors.brandGoldDeep;
    final indigo = dark ? const Color(0xFFA9A6F5) : AppColors.brandPrimary;

    final streak = HomeStatTile(
      key: const Key('home_streak_tile'),
      icon: Icons.local_fire_department_outlined,
      accent: gold,
      title: streakDays > 0
          ? context.tr(TranslationKeys.homeDayStreak, {'count': streakDays})
          : context.tr(TranslationKeys.homeNoStreakYet),
      subtitle: streakDays > 0
          ? context.tr(TranslationKeys.homeKeepItAlive)
          : context.tr(TranslationKeys.homeStartStreakHint),
      onTap: onStreakTap,
    );

    if (!showReview) return streak;

    final review = HomeStatTile(
      key: const Key('home_review_tile'),
      icon: Icons.psychology_outlined,
      accent: indigo,
      title: dueCount > 0
          ? context.tr(TranslationKeys.homeToReview, {'count': dueCount})
          : context.tr(TranslationKeys.homeAllCaughtUp),
      subtitle: dueCount > 0
          ? (nextReviewReference ??
              context.tr(TranslationKeys.homeMemoryVerses))
          : context.tr(TranslationKeys.homeNothingDue),
      // Several due: name the first and count the rest, so the reference is
      // not read as the only verse waiting.
      subtitleSuffix: dueCount > 1 && nextReviewReference != null
          ? context.tr(TranslationKeys.homeReviewMore, {'count': dueCount - 1})
          : null,
      onTap: onReviewTap,
    );

    // Side by side on a normal phone; stacked on a narrow one, where two
    // tiles would each be too slim to show their text in full.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < homeTilesStackBelowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [streak, const SizedBox(height: 10), review],
          );
        }
        // Equal heights even when one tile's text wraps to more lines.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: streak),
              const SizedBox(width: 10),
              Expanded(child: review),
            ],
          ),
        );
      },
    );
  }
}

/// Circular progress ring used on learning-path rows.
class HomeProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color track;
  final double size;

  /// Optional icon drawn in the middle of the ring.
  final IconData? centerIcon;

  const HomeProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.track,
    this.size = 36,
    this.centerIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          track: track,
        ),
        child: centerIcon == null
            ? null
            : Center(
                child: Icon(centerIcon, size: size * 0.44, color: color),
              ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false,
          paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// A tappable row: progress ring, title, subtitle, chevron.
class HomePathRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color accent;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Icon shown inside the progress ring (e.g. the learning path's icon).
  final IconData? ringIcon;

  const HomePathRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.accent,
    this.onTap,
    this.icon,
    this.ringIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = _HomeCardColors.of(context);
    return HomePressable(
        builder: (onHighlight) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onHighlightChanged: onHighlight,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: _cardDecoration(c, 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (icon != null)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 18, color: accent),
                        )
                      else
                        HomeProgressRing(
                          progress: progress,
                          color: accent,
                          track: c.ringTrack,
                          size: ringIcon == null ? 36 : 40,
                          centerIcon: ringIcon,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.inter(
                                  fontSize: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 18, color: c.chevron),
                    ],
                  ),
                ),
              ),
            ));
  }
}

/// Subtitle for a learning path row: "3 of 8 · Next: God is Love" once
/// started and the next topic is known, "3 of 8 topics" otherwise, "Start
/// here · 8 topics" before.
String homePathSubtitle(BuildContext context, LearningPath path) {
  if (path.progressPercentage > 0 || path.isEnrolled) {
    final next = path.nextTopicTitle;
    if (next != null && !path.isCompleted) {
      return context.tr(TranslationKeys.homeTopicsProgressNext, {
        'done': path.topicsCompleted,
        'total': path.topicsCount,
        'title': next,
      });
    }
    return context.tr(TranslationKeys.homeTopicsProgress, {
      'done': path.topicsCompleted,
      'total': path.topicsCount,
    });
  }
  return context.tr(TranslationKeys.homeStartHere, {'count': path.topicsCount});
}

/// Accent for a path's ring: the path's own colour when it parses, gold
/// otherwise.
Color homePathAccent(BuildContext context, LearningPath path) {
  final hex = path.color.replaceFirst('#', '');
  if (hex.length == 6) {
    final value = int.tryParse(hex, radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.brandGold
      : AppColors.brandGoldDeep;
}

/// Card press feedback: a slight shrink while the finger is down. Only the
/// pressed card rebuilds, and only on press and release; the scale itself
/// is a transform on an already-painted layer.
class HomePressable extends StatefulWidget {
  final Widget Function(ValueChanged<bool> onHighlightChanged) builder;

  const HomePressable({super.key, required this.builder});

  @override
  State<HomePressable> createState() => _HomePressableState();
}

class _HomePressableState extends State<HomePressable> {
  bool _pressed = false;

  void _onHighlight(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _pressed && !reduce ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.builder(_onHighlight),
    );
  }
}

/// Placeholder learning-path card shown under the lock overlay on Home: the
/// same card as the path rows around it, with a line on what paths offer.
class HomeLockedPathsCard extends StatelessWidget {
  const HomeLockedPathsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final accent = palette.accentIcon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.route_outlined, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.learningPathsTitle),
                      style: AppFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.learningPathsSubtitle),
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(TranslationKeys.appStatusLockedPathsBody),
            style: AppFonts.inter(
              fontSize: 13,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
