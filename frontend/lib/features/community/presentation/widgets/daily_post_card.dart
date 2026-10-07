import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/copy_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/study_guide_chip.dart';
import 'package:disciplefy_bible_study/shared/widgets/clickable_scripture_text.dart';
import 'package:disciplefy_bible_study/shared/widgets/scripture_verse_sheet.dart';

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
/// - `📖` → the lesson title (Poppins, emoji stripped)
/// - `✨` → the opening hook (emoji stripped)
/// - `✝️` → a scripture reference chip; tapping it opens the verse when the
///   reference is recognised
/// - anything else → body text
///
/// Older daily posts without a `✨` line simply read as body text. Older posts
/// also carried a `💬` reflection question; it is hidden — the question lives
/// in the study guide the card links to.
class DailyPostBody extends StatelessWidget {
  /// Raw post content (`FellowshipPostEntity.content`).
  final String content;

  /// Accent used for the scripture chip tint — see [dailyPostAccent].
  final Color accent;

  const DailyPostBody({
    required this.content,
    required this.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('💬'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) _DailyLine(line: line.trim(), accent: accent),
      ],
    );
  }
}

/// The daily post as the reader sees it, as plain text for copying: the
/// lesson title, the hook, the scripture reference and any other lines, with
/// the leading marker emoji removed and the hidden `💬` question left out.
String dailyPostPlainText(String content) => content
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty && !l.startsWith('💬'))
    .map((l) {
      for (final marker in const ['📖', '✨', '✝️', '✝']) {
        if (l.startsWith(marker)) return l.substring(marker.length).trim();
      }
      return l;
    })
    .where((l) => l.isNotEmpty)
    .join('\n');

/// Card rendering for a system-generated daily study post (`postType ==
/// 'daily'`).
///
/// Gold hairline with a faint gold tint at the top; header with the Discipler
/// mark and a "Daily study" chip; the lesson eyebrow (when the post carries
/// its path/lesson), the body laid out by [DailyPostBody], then
/// one action row led by a "Start study" pill (opens the guide exactly as the
/// old guide chip did), then reaction, replies and share.
class DailyPostCard extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  /// Adds Edit/Delete to the menu (mentors and admins in the live feed).
  /// Everyone gets the menu's "Copy text" in interactive mode.
  final bool canManage;

  /// False renders read-only counts instead of the reaction/replies buttons
  /// (no [FellowshipFeedBloc] needed).
  final bool interactive;

  const DailyPostCard({
    required this.post,
    required this.fellowshipId,
    this.onCommentTap,
    this.onShareTap,
    this.canManage = false,
    this.interactive = true,
    super.key,
  });

  /// "{PATH} · LESSON N", from whatever the post carries, or null.
  String? _eyebrow(BuildContext context) {
    final guide = post.guideTitle?.trim() ?? '';
    // The post body usually opens with the lesson title; repeating it in the
    // label above says nothing new, so keep just "LESSON N" then.
    final repeatsTitle = guide.isNotEmpty &&
        post.content.trimLeft().toLowerCase().contains(guide.toLowerCase());
    final parts = <String>[
      if (guide.isNotEmpty && !repeatsTitle) guide,
      if (post.lessonIndex != null)
        context.tr(TranslationKeys.communitySharedLesson,
            {'number': post.lessonIndex}),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final accent = dailyPostAccent(context);
    final gold = palette.gold;
    final eyebrow = _eyebrow(context);
    final radius = BorderRadius.circular(22);
    final copyText = dailyPostPlainText(post.content);
    final hasMenu = interactive && (canManage || copyText.isNotEmpty);

    return LongPressMenuScope(
      builder: (context, menuKey) => GestureDetector(
        onLongPress: hasMenu ? () => openLongPressMenu(menuKey) : null,
        behavior: HitTestBehavior.opaque,
        child: _buildCard(context, l10n, palette, accent, gold, eyebrow, radius,
            copyText, hasMenu ? menuKey : null),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppLocalizations l10n,
    ReaderPalette palette,
    Color accent,
    Color gold,
    String? eyebrow,
    BorderRadius radius,
    String copyText,
    GlobalKey<PopupMenuButtonState<String>>? menuKey,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: gold.withValues(alpha: palette.isDark ? 0.38 : 0.45),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.45],
          colors: [
            Color.alphaBlend(
              gold.withValues(alpha: palette.isDark ? 0.10 : 0.10),
              palette.card,
            ),
            palette.card,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                const DisciplerAvatar(radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.disciplerName,
                                style: AppFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                ),
                              ),
                              const DisciplerAiChip(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          PostTimestamp(createdAt: post.createdAt),
                        ],
                      ),
                      const DailyStudyChip(),
                    ],
                  ),
                ),
                if (menuKey != null)
                  _DailyPostMenu(
                    menuKey: menuKey,
                    post: post,
                    canManage: canManage,
                    copyText: copyText,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    CommunitySectionLabel(eyebrow,
                        color: palette.goldOnTint, fontSize: 11.5),
                    const SizedBox(height: 8),
                  ],
                  // ── Body ─────────────────────────────────────────────
                  DailyPostBody(content: post.content, accent: accent),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ── Footer ─────────────────────────────────────────────────
            if (interactive)
              // One action row: "Start study" leads as the primary action,
              // then reaction, replies and share.
              FellowshipPostFooter(
                post: post,
                accentColor: accent,
                onCommentTap: onCommentTap,
                onShareTap: onShareTap,
                leading: _StartStudyButton(post: post),
              )
            else ...[
              _StartStudyButton(post: post),
              const SizedBox(height: 10),
              FellowshipPostPreviewFooter(post: post),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gold "Daily study" chip with a book icon.
class DailyStudyChip extends StatelessWidget {
  const DailyStudyChip({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gold = palette.gold;
    final ink = palette.goldOnTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: palette.isDark ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: ink),
          const SizedBox(width: 5),
          // Flexible + wrapping: in a narrow header the chip wraps its
          // label rather than overflowing or cutting it.
          Flexible(
            child: Text(
              context.tr(TranslationKeys.communitySharedDailyStudy),
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The daily post's ⋮ menu: "Copy text" for everyone, plus Edit and Delete
/// for mentors and admins.
class _DailyPostMenu extends StatelessWidget {
  /// Lets a long-press on the card open this menu.
  final GlobalKey<PopupMenuButtonState<String>> menuKey;
  final FellowshipPostEntity post;
  final bool canManage;
  final String copyText;

  const _DailyPostMenu({
    required this.post,
    required this.canManage,
    required this.copyText,
    required this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return PopupMenuButton<String>(
      key: menuKey,
      tooltip: context.tr(TranslationKeys.communitySharedMoreOptions),
      icon: Icon(Icons.more_vert, size: 20, color: palette.muted),
      color: palette.isDark ? palette.raised : palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'copy') {
          copyCommunityText(context, copyText);
        } else if (value == 'edit') {
          editDisciplerPost(context, post);
        } else if (value == 'delete') {
          context
              .read<FellowshipFeedBloc>()
              .add(FellowshipPostDeleteRequested(postId: post.id));
        }
      },
      itemBuilder: (_) => [
        if (copyText.isNotEmpty)
          PopupMenuItem<String>(
            value: 'copy',
            child: Row(
              children: [
                Icon(Icons.copy_rounded, color: palette.muted, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    context.tr(TranslationKeys.communityPostCopyText),
                    style: AppFonts.inter(color: palette.text),
                  ),
                ),
              ],
            ),
          ),
        if (canManage) ...[
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: palette.muted, size: 20),
                const SizedBox(width: 10),
                Text(l10n.editAction,
                    style: AppFonts.inter(color: palette.text)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: context.appError, size: 20),
                const SizedBox(width: 10),
                Text(l10n.deleteAction,
                    style: AppFonts.inter(color: context.appError)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "Start study": opens the lesson's guide through
/// [openFellowshipStudyGuide], with the same arguments the old guide chip
/// passed.
class _StartStudyButton extends StatefulWidget {
  final FellowshipPostEntity post;

  const _StartStudyButton({required this.post});

  @override
  State<_StartStudyButton> createState() => _StartStudyButtonState();
}

class _StartStudyButtonState extends State<_StartStudyButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = widget.post;
    return CommunityCtaPill(
      label: context.tr(TranslationKeys.communitySharedStartStudy),
      icon: Icons.play_arrow_outlined,
      compact: true,
      loading: _loading,
      onPressed: () => openFellowshipStudyGuide(
        context,
        studyGuideId: post.studyGuideId,
        title: post.guideTitle ?? post.topicTitle ?? l10n.openFullStudy,
        inputType: 'topic',
        inputValue: post.topicTitle,
        language: post.guideLanguage,
        onLoadingChanged: (loading) {
          if (mounted) setState(() => _loading = loading);
        },
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
    final palette = ReaderPalette.of(context);
    if (line.startsWith('📖')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          line.substring('📖'.length).trim(),
          style: AppFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: palette.text,
          ),
        ),
      );
    }
    if (line.startsWith('✨')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          line.substring('✨'.length).trim(),
          style: AppFonts.inter(
            fontSize: 15.5,
            height: 1.55,
            color: palette.isDark
                ? palette.text.withValues(alpha: 0.82)
                : palette.text.withValues(alpha: 0.78),
          ),
        ),
      );
    }
    if (line.startsWith('✝️') || line.startsWith('✝')) {
      final reference =
          line.replaceFirst('✝️', '').replaceFirst('✝', '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: ScriptureReferenceChip(reference: reference),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        line,
        style: AppFonts.inter(
          fontSize: 15,
          color: palette.muted,
          height: 1.55,
        ),
      ),
    );
  }
}

/// Raised chip with a bookmark icon naming a scripture reference. When the
/// reference is recognised by the scripture regex it is tappable and opens
/// the verse in [ScriptureVerseSheet]; otherwise it is plain text.
class ScriptureReferenceChip extends StatelessWidget {
  final String reference;

  const ScriptureReferenceChip({super.key, required this.reference});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final match = ClickableScriptureText.scripturePattern.firstMatch(reference);
    final tappable = match != null;
    final radius = BorderRadius.circular(20);
    return Material(
      color: palette.isDark
          ? Colors.white.withValues(alpha: 0.07)
          : palette.raised,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: tappable
            ? () => ScriptureVerseSheet.show(context,
                reference: match.group(0)!.trim())
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_border_rounded,
                    size: 17, color: palette.accentIcon),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    reference,
                    style: AppFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: palette.accentIcon,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
