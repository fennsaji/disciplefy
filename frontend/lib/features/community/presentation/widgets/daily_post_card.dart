import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import 'discipler_badges.dart';
import 'reaction_button.dart';
import 'study_guide_chip.dart';
import 'fellowship_post_card.dart';

/// Accent colour used by daily study post rendering, in both the feed card and
/// the guide discussion thread.
Color dailyPostAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppColors.brandHighlightDark
        : const Color(0xFF8B6914);

/// Renders the body of a daily study post.
///
/// The content is the formatter's plain text output. Lines are rendered with
/// light styling based on their leading emoji:
/// - `📖` → small eyebrow with the lesson title
/// - `✨` → the headline hook (largest text, emoji stripped)
/// - `✝️` → verse reference in a pill
/// - `💬` → semibold reflection prompt
/// - anything else → plain body text
///
/// Older daily posts without a `✨` line simply read as body text.
class DailyPostBody extends StatelessWidget {
  /// Raw post content (`FellowshipPostEntity.content`).
  final String content;

  /// Accent used for the verse pill tint — see [dailyPostAccent].
  final Color accent;

  const DailyPostBody({
    required this.content,
    required this.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) _DailyLine(line: line, accent: accent),
      ],
    );
  }
}

/// Card rendering for a system-generated daily study post (`postType ==
/// 'daily'`).
///
/// The body is laid out by [DailyPostBody]; the guide itself opens through the
/// [StudyGuideChip] under it.
class DailyPostCard extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  const DailyPostCard({
    required this.post,
    required this.fellowshipId,
    this.onCommentTap,
    this.onShareTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3A3018) : AppColors.brandHighlight;
    final accent = dailyPostAccent(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(60), width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              const DisciplerAvatar(radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.disciplerName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const DisciplerAiChip(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              l10n.postTypeDaily,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Body ───────────────────────────────────────────────────
          DailyPostBody(content: post.content, accent: accent),

          const SizedBox(height: 10),
          StudyGuideChip(
            studyGuideId: post.studyGuideId,
            title: post.guideTitle ?? post.topicTitle ?? l10n.openFullStudy,
            inputType: 'topic',
            inputValue: post.topicTitle,
            language: post.guideLanguage,
          ),
          const SizedBox(height: 12),

          // ── Footer ─────────────────────────────────────────────────
          FellowshipPostFooter(
            post: post,
            accentColor: accent,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
          ),
        ],
      ),
    );
  }
}

class _DailyLine extends StatelessWidget {
  final String line;
  final Color accent;

  const _DailyLine({required this.line, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (line.startsWith('📖')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          line,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: context.appTextSecondary,
          ),
        ),
      );
    }
    if (line.startsWith('✨')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          line.substring(1).trim(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: context.appTextPrimary,
          ),
        ),
      );
    }
    if (line.startsWith('✝️')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withAlpha(24),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            line,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: context.appTextPrimary,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    if (line.startsWith('💬')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          line,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: context.appTextPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}
