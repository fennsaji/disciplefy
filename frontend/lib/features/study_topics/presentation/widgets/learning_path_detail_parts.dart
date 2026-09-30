import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';

/// Letter spacing for tracked eyebrows. Indic scripts render their conjuncts
/// apart when tracked, so only Latin text is spaced out.
double _trackingFor(String text) =>
    text.codeUnits.every((c) => c < 0x0250) ? 1.8 : 0;

/// Row of round icon actions over the photo wash: back on the left, the
/// page's own actions (share, download) on the right.
class PathDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final List<Widget> actions;

  const PathDetailTopBar({
    super.key,
    required this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: palette.text),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// Eyebrow, title, clamped description and meta row of a learning path.
class PathDetailHeader extends StatefulWidget {
  /// Localised disciple level, e.g. "Seeker".
  final String levelLabel;
  final String category;
  final String title;
  final String description;
  final int topicsCount;
  final int totalXp;
  final int estimatedDays;

  /// Large faint motif drawn behind the top-right of the header.
  final IconData icon;

  const PathDetailHeader({
    super.key,
    required this.levelLabel,
    required this.category,
    required this.title,
    required this.description,
    required this.topicsCount,
    required this.totalXp,
    required this.estimatedDays,
    required this.icon,
  });

  @override
  State<PathDetailHeader> createState() => _PathDetailHeaderState();
}

class _PathDetailHeaderState extends State<PathDetailHeader> {
  /// Whether the description shows its full text rather than the 2-line
  /// preview.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final eyebrow = [
      widget.levelLabel,
      if (widget.category.trim().isNotEmpty) widget.category.trim(),
    ].join(' · ').toUpperCase();

    return Stack(
      children: [
        Positioned(
          top: -8,
          right: 12,
          child: ExcludeSemantics(
            child: Icon(
              widget.icon,
              size: 104,
              color: palette.text.withValues(alpha: 0.06),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: _trackingFor(eyebrow),
                  color: palette.gold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: AppFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: palette.text,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDescription(context, palette),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.menu_book_outlined,
                    text:
                        '${widget.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}',
                  ),
                  _MetaItem(
                    icon: Icons.star_outline_rounded,
                    text:
                        '${widget.totalXp} ${context.tr(TranslationKeys.learningPathsXp)}',
                  ),
                  _MetaItem(
                    icon: Icons.timer_outlined,
                    text:
                        '${widget.estimatedDays} ${context.tr(TranslationKeys.learningPathsDays)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, ReaderPalette palette) {
    final style = AppFonts.inter(
      fontSize: 15,
      height: 1.5,
      // Brighter than muted: it sits on the photo wash.
      color: palette.text.withValues(alpha: 0.82),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.description, style: style),
        maxLines: 2,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: style,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows)
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('path-description-toggle'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.tr(_expanded
                              ? TranslationKeys.commonShowLess
                              : TranslationKeys.commonShowMore),
                          style: AppFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.accentIcon,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: palette.accentIcon,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: palette.text.withValues(alpha: 0.75)),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppFonts.inter(
            fontSize: 14,
            color: palette.text.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// "3 of 8 done" with the gold percentage and bar.
class PathDetailProgress extends StatelessWidget {
  final int completed;
  final int total;
  final int percent;
  final bool isCompleted;

  const PathDetailProgress({
    super.key,
    required this.completed,
    required this.total,
    required this.percent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final accent = isCompleted ? AppColors.success : palette.gold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.learningPathsTopicsCompleted,
                      {'completed': completed, 'total': total}),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isCompleted) ...[
                Icon(Icons.check_circle_rounded, size: 16, color: accent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    context.tr(TranslationKeys.learningPathsCompleted),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$percent%',
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: palette.outline,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a topic sits in the learner's progress through the path.
enum PathTopicStatus { completed, current, upcoming, locked }

/// One topic of a learning path.
///
/// The current topic is a raised card with a gold hairline, a gold number
/// disc and an "up next" line; the others are flat rows.
class PathTopicRow extends StatelessWidget {
  /// 1-based position shown in the disc.
  final int number;
  final String title;
  final String category;
  final int xp;
  final bool isMilestone;
  final PathTopicStatus status;

  /// Detail line of the current topic, e.g. "Next Topic · Standard · 8 min".
  final String? upNextLine;
  final VoidCallback? onTap;

  const PathTopicRow({
    super.key,
    required this.number,
    required this.title,
    required this.category,
    required this.xp,
    required this.status,
    this.isMilestone = false,
    this.upNextLine,
    this.onTap,
  });

  bool get _isCurrent => status == PathTopicStatus.current;
  bool get _isLocked => status == PathTopicStatus.locked;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(16);

    final subline = _isCurrent
        ? [if (upNextLine != null) upNextLine!, '+$xp XP'].join(' · ')
        : [if (category.trim().isNotEmpty) category.trim(), '+$xp XP']
            .join(' · ');

    final row = Row(
      children: [
        _Disc(number: number, status: status, palette: palette),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: status == PathTopicStatus.completed
                            ? palette.muted
                            : palette.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMilestone)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 3),
                      child: MilestoneBadge(),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subline,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: _isCurrent ? FontWeight.w500 : FontWeight.w400,
                  color: _isCurrent ? palette.gold : palette.dim,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (_isCurrent)
          Icon(Icons.play_arrow_outlined, size: 26, color: palette.gold)
        else if (!_isLocked)
          Icon(Icons.chevron_right_rounded, size: 22, color: palette.dim),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Opacity(
        opacity: _isLocked ? 0.5 : 1,
        child: Semantics(
          button: !_isLocked,
          enabled: !_isLocked,
          child: Material(
            color: _isCurrent ? palette.card : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: _isCurrent
                  ? BorderSide(color: palette.gold.withValues(alpha: 0.45))
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isLocked ? null : onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isCurrent ? 12 : 0,
                  vertical: _isCurrent ? 14 : 10,
                ),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  final int number;
  final PathTopicStatus status;
  final ReaderPalette palette;

  const _Disc({
    required this.number,
    required this.status,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Widget child;
    switch (status) {
      case PathTopicStatus.completed:
        fill =
            AppColors.success.withValues(alpha: palette.isDark ? 0.16 : 0.14);
        child =
            const Icon(Icons.check_rounded, size: 18, color: AppColors.success);
      case PathTopicStatus.current:
        fill = palette.gold;
        child = Text(
          '$number',
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.isDark ? const Color(0xFF1A1405) : Colors.white,
          ),
        );
      case PathTopicStatus.upcoming:
        fill = palette.raised;
        child = Text(
          '$number',
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        );
      case PathTopicStatus.locked:
        fill = palette.raised;
        child = Icon(Icons.lock_rounded, size: 15, color: palette.dim);
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Full-width primary pill pinned to the bottom of the path page.
class PathDetailCtaBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const PathDetailCtaBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35],
          colors: [palette.page.withValues(alpha: 0), palette.page],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Semantics(
            button: true,
            child: Material(
              color: palette.ctaFill,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('path-detail-cta'),
                onTap: onPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 22, color: palette.ctaInk),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: palette.ctaInk,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered spinner, icon or message under the top bar for the loading,
/// enrolling and error states.
class PathDetailStatusView extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? message;
  final Color? messageColor;
  final Widget? action;

  const PathDetailStatusView({
    super.key,
    required this.leading,
    required this.title,
    this.message,
    this.messageColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          leading,
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: message == null ? 14 : 16,
              fontWeight: message == null ? FontWeight.w400 : FontWeight.w600,
              color: message == null ? palette.muted : palette.text,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: messageColor ?? palette.muted,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
