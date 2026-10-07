import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/utils/fellowship_lesson_language.dart';
import 'package:disciplefy_bible_study/features/community/data/services/saved_guide_fetcher.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_guide_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/copy_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/markdown_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/daily_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_edit_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/reaction_button.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// Regex matching a mention token like `@Discipler` or `@Jane.Doe` in post
/// or comment content.
final RegExp _mentionRegex = RegExp(r'(@[A-Za-z]\w*(?:\.\w+)*)');

/// Splits [text] into [TextSpan]s, styling `@mention` tokens with
/// [mentionStyle] and everything else with [baseStyle].
List<TextSpan> mentionSpans(
  String text,
  TextStyle baseStyle,
  TextStyle mentionStyle,
) {
  final spans = <TextSpan>[];
  var lastEnd = 0;
  for (final match in _mentionRegex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, match.start),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(text: match.group(0), style: mentionStyle));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }
  return spans;
}

/// The whole of [post] as plain text for "Copy text" — never the clamped
/// feed preview. `@mentions` stay as typed (`@Name`); Discipler text loses
/// any stray markdown emphasis markers. A shared guide with no message falls
/// back to the guide's title and summary. Empty when there is nothing to copy.
String postCopyText(FellowshipPostEntity post) {
  if (post.isDaily) return dailyPostPlainText(post.content);
  final body =
      (post.authorIsSystem ? stripEmphasisMarkers(post.content) : post.content)
          .trim();
  if (body.isNotEmpty) return body;
  return [post.guideTitle?.trim(), post.guideSummary?.trim()]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join('\n');
}

/// Returns the popup menu item keys to show for [post], in display order.
///
/// - `'share'` is always present.
/// - `'copy'` follows it whenever the post has text to copy.
/// - `'delete'` is shown for mentors, admins, or the post's own author.
/// - Discipler-authored (system) posts never show `'report'`/`'block'`.
/// - `'report'` is shown for non-mentors viewing someone else's post.
/// - `'block'` is shown for any post that isn't the viewer's own.
List<String> postMenuItems(
  FellowshipPostEntity post, {
  required bool isMentor,
  required bool isAdmin,
  String? currentUserId,
}) {
  final items = <String>['share', if (postCopyText(post).isNotEmpty) 'copy'];
  final own = post.authorUserId == currentUserId;
  if ((isMentor || isAdmin) && post.authorIsSystem) items.add('edit');
  if (isMentor || isAdmin || own) items.add('delete');
  if (post.authorIsSystem) return items;
  if (!isMentor && !own) items.add('report');
  if (!own) items.add('block');
  return items;
}

/// Opens the editor for a Discipler post and saves the result through
/// [FellowshipFeedBloc].
Future<void> editDisciplerPost(
    BuildContext context, FellowshipPostEntity post) async {
  final bloc = context.read<FellowshipFeedBloc>();
  final text = await showDisciplerEditDialog(
    context,
    initialText: post.content,
    maxLength: 4000,
  );
  if (text != null) {
    bloc.add(FellowshipPostEditRequested(postId: post.id, content: text));
  }
}

// ---------------------------------------------------------------------------
// Public shared post card
// ---------------------------------------------------------------------------

/// Shared post card used in both the fellowship feed and the home screen
/// recent activity preview.
///
/// - `interactive: true`  → full reaction button (tap/long-press), comment
///   button, and overflow menu. Reads [FellowshipFeedBloc] from context.
/// - `interactive: false` → read-only view with static reaction/comment
///   counts. No BLoC needed.
///
/// Daily study posts (`postType == 'daily'`) render as a [DailyPostCard].
///
/// Feeds pass [feedMaxContentLines] as [maxContentLines]: the whole post
/// shows, and only an unusually long one is clamped — with an ellipsis and a
/// "Read more" link that opens it. The post page passes nothing (no clamp).
class FellowshipPostCard extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  /// Whether this card has interactive reaction/reply buttons.
  /// Set to `false` for the Recent Activity preview.
  final bool interactive;

  /// Clamps the content text, adding a "Read more" link (which calls
  /// [onPostTap]) when it overflows. `null` = no limit. Ignored when
  /// [onPostTap] is null, since nothing could then show the rest.
  final int? maxContentLines;

  /// Clamp used by feed cards. Generous on purpose: members' posts are
  /// short reflections and should read in full; this only stops a wall of
  /// text from swallowing the feed.
  static const int feedMaxContentLines = 12;

  /// Called when the comment button is tapped (interactive mode only).
  /// If null, comment button is hidden.
  final VoidCallback? onCommentTap;

  /// Called when the "Report" menu item is tapped (interactive mode only).
  /// If null, report item is hidden.
  final VoidCallback? onReportTap;

  /// Called when the "Block" menu item is tapped (interactive mode only).
  final VoidCallback? onBlockTap;

  /// Whether the current viewer is a global admin. Admins may delete any
  /// Discipler-authored post even when not a fellowship mentor.
  final bool isAdmin;

  /// Called when the "Share" menu item / footer share icon is tapped.
  final VoidCallback? onShareTap;

  /// Called when the card itself (outside its buttons) is tapped — opens the
  /// post's own page. If null, the card is not tappable.
  final VoidCallback? onPostTap;

  const FellowshipPostCard({
    required this.post,
    required this.fellowshipId,
    this.isMentor = false,
    this.currentUserId,
    this.interactive = true,
    this.maxContentLines,
    this.onCommentTap,
    this.onReportTap,
    this.onBlockTap,
    this.isAdmin = false,
    this.onShareTap,
    this.onPostTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (post.isDaily) {
      return DailyPostCard(
        post: post,
        fellowshipId: fellowshipId,
        canManage: interactive && (isMentor || isAdmin),
        onCommentTap: onCommentTap,
        onShareTap: onShareTap,
        interactive: interactive,
      );
    }

    final palette = ReaderPalette.of(context);
    final accentColor =
        postTypeAccentColor(post.postType, isDark: palette.isDark);
    final isSystem = post.authorIsSystem;
    final l10n = AppLocalizations.of(context)!;

    // Long-press anywhere on the card opens its ⋮ menu (Copy text, Share…).
    return LongPressMenuScope(
      builder: (context, menuKey) => GestureDetector(
        onTap: onPostTap,
        onLongPress: interactive ? () => openLongPressMenu(menuKey) : null,
        behavior: HitTestBehavior.opaque,
        child:
            _buildCard(context, palette, accentColor, isSystem, l10n, menuKey),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ReaderPalette palette,
    Color accentColor,
    bool isSystem,
    AppLocalizations l10n,
    GlobalKey<PopupMenuButtonState<String>> menuKey,
  ) {
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        // Discipler's own (non-daily) posts keep a faint gold wash so they
        // still read as the helper's voice rather than a member's.
        gradient: isSystem
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    palette.gold
                        .withValues(alpha: palette.isDark ? 0.14 : 0.06),
                    palette.card,
                  ),
                  palette.card,
                ],
              )
            : null,
        borderRadius: radius,
        border: Border.all(color: palette.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, interactive ? 8 : 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                isSystem
                    ? const DisciplerAvatar(radius: 18)
                    : MemberAvatar(
                        displayName: post.authorDisplayName,
                        avatarUrl: post.authorAvatarUrl,
                        radius: 18,
                      ),
                const SizedBox(width: 12),
                // Wrap: the type chip sits at the right when it fits beside
                // the name, and drops under it on narrow screens / long
                // hi-ml labels instead of squeezing the name away.
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  isSystem
                                      ? l10n.disciplerName
                                      : post.authorDisplayName,
                                  style: AppFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSystem) ...[
                                const SizedBox(width: 6),
                                const DisciplerAiChip(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          PostTimestamp(createdAt: post.createdAt),
                        ],
                      ),
                      if (post.postType != 'general')
                        PostTypeChip(postType: post.postType),
                    ],
                  ),
                ),
                // Overflow menu — interactive mode only
                if (interactive)
                  _PostMenuButton(
                    menuKey: menuKey,
                    post: post,
                    isMentor: isMentor,
                    isAdmin: isAdmin,
                    currentUserId: currentUserId,
                    onReportTap: onReportTap,
                    onBlockTap: onBlockTap,
                    onShareTap: onShareTap,
                  )
                else
                  const SizedBox(width: 0),
              ],
            ),
            const SizedBox(height: 12),

            // ── Content ────────────────────────────────────────────────────
            if (post.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: interactive ? 12 : 0),
                child: FellowshipPostContent(
                  content: post.content,
                  maxLines: maxContentLines,
                  onReadMore: onPostTap,
                  // On the post's own page (no tap-through) the text can be
                  // selected and partly copied; mentions are not links, so
                  // nothing competes with the selection gestures.
                  selectable: interactive && onPostTap == null,
                ),
              ),

            // ── study_note link preview ─────────────────────────────────
            if (post.postType == 'study_note' &&
                (post.topicId != null || post.guideTitle != null)) ...[
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(right: interactive ? 12 : 0),
                child: _StudyNoteLink(
                  post: post,
                  fellowshipId: fellowshipId,
                  isMentor: isMentor,
                  accentColor: accentColor,
                ),
              ),
            ],

            // ── shared_guide link preview ────────────────────────────────
            if (post.postType == 'shared_guide' &&
                (post.studyGuideId != null || post.guideTitle != null)) ...[
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(right: interactive ? 12 : 0),
                child: _SharedGuideLink(post: post),
              ),
            ],

            if (isSystem) ...[
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(right: interactive ? 12 : 0),
                child: const DisciplerFooterNote(),
              ),
            ],

            const SizedBox(height: 12),

            // ── Footer ─────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(right: interactive ? 4 : 0),
              child: interactive
                  ? FellowshipPostFooter(
                      post: post,
                      accentColor: accentColor,
                      onCommentTap: onCommentTap,
                      onShareTap: onShareTap,
                    )
                  : FellowshipPostPreviewFooter(post: post),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post body
// ---------------------------------------------------------------------------

/// A member post's text: every paragraph and line break as written, with
/// `@mentions` in the accent colour.
///
/// With [maxLines] and [onReadMore] both set, text that would run past
/// [maxLines] ends in an ellipsis followed by a visible "Read more" link
/// that calls [onReadMore] — so a clamped post never looks complete.
///
/// [selectable] lets the reader select (and copy part of) the unclamped
/// text, as on the post's own page.
class FellowshipPostContent extends StatelessWidget {
  final String content;
  final int? maxLines;
  final VoidCallback? onReadMore;
  final bool selectable;

  const FellowshipPostContent({
    required this.content,
    this.maxLines,
    this.onReadMore,
    this.selectable = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final span = TextSpan(
      children: mentionSpans(
        content,
        AppFonts.inter(fontSize: 15.5, color: palette.text, height: 1.55),
        AppFonts.inter(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: palette.accentIcon,
          height: 1.55,
        ),
      ),
    );
    final limit = maxLines;
    if (limit == null || onReadMore == null) {
      final text = Text.rich(span, key: const Key('post_content'));
      return selectable ? SelectionArea(child: text) : text;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: span,
        maxLines: limit,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      if (!overflows) return Text.rich(span, key: const Key('post_content'));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            span,
            key: const Key('post_content'),
            maxLines: limit,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(
            key: const Key('post_read_more'),
            onPressed: onReadMore,
            style: TextButton.styleFrom(
              foregroundColor: palette.accentIcon,
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              AppLocalizations.of(context)!.feedReadMore,
              style: AppFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: palette.accentIcon,
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Overflow menu
// ---------------------------------------------------------------------------

class _PostMenuButton extends StatelessWidget {
  /// Lets a long-press on the card open this menu.
  final GlobalKey<PopupMenuButtonState<String>> menuKey;
  final FellowshipPostEntity post;
  final bool isMentor;
  final bool isAdmin;
  final String? currentUserId;
  final VoidCallback? onReportTap;
  final VoidCallback? onBlockTap;
  final VoidCallback? onShareTap;

  const _PostMenuButton({
    required this.post,
    required this.isMentor,
    required this.isAdmin,
    required this.currentUserId,
    required this.onReportTap,
    required this.onBlockTap,
    required this.onShareTap,
    required this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      bool destructive = false,
    }) {
      final color = destructive ? context.appError : palette.text;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon,
                color: destructive ? context.appError : palette.muted,
                size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, style: AppFonts.inter(color: color)),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      key: menuKey,
      tooltip: context.tr(TranslationKeys.communitySharedMoreOptions),
      icon: Icon(Icons.more_vert, size: 20, color: palette.muted),
      color: palette.isDark ? palette.raised : palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == 'copy') {
          copyCommunityText(context, postCopyText(post));
        } else if (value == 'edit') {
          editDisciplerPost(context, post);
        } else if (value == 'delete') {
          context.read<FellowshipFeedBloc>().add(
                FellowshipPostDeleteRequested(postId: post.id),
              );
        } else if (value == 'report') {
          onReportTap?.call();
        } else if (value == 'block') {
          onBlockTap?.call();
        } else if (value == 'share') {
          onShareTap?.call();
        }
      },
      itemBuilder: (_) => [
        for (final key in postMenuItems(
          post,
          isMentor: isMentor,
          isAdmin: isAdmin,
          currentUserId: currentUserId,
        ))
          switch (key) {
            'share' => item('share', Icons.share_outlined, l10n.sharePost),
            'copy' => item('copy', Icons.copy_rounded,
                context.tr(TranslationKeys.communityPostCopyText)),
            'edit' => item('edit', Icons.edit_outlined, l10n.editAction),
            'delete' => item(
                'delete', Icons.delete_outline_rounded, l10n.deleteAction,
                destructive: true),
            'report' => item('report', Icons.flag_outlined, l10n.reportTitle),
            _ => item('block', Icons.block, l10n.blockUserTitle,
                destructive: true),
          },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Post-type colours (shared across widgets)
// ---------------------------------------------------------------------------

/// Colour that identifies a post type: its chip, and the reaction pill once
/// the viewer has reacted.
///
/// Prayer pink, praise gold, question sky blue, study note green, shared
/// study guide teal; anything else takes the gold accent. Light theme uses
/// darker shades so the text on a pale tint stays readable.
Color postTypeAccentColor(String postType, {bool isDark = false}) {
  switch (postType) {
    case 'prayer':
      return isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D);
    case 'praise':
      return isDark ? AppColors.brandGold : AppColors.brandGoldDeep;
    case 'question':
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D5FC4);
    case 'study_note':
      return isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    case 'shared_guide':
      return isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E);
    case 'daily':
      return AppColors.brandHighlightDark;
    default:
      return isDark ? AppColors.brandGold : AppColors.brandGoldDeep;
  }
}

// ---------------------------------------------------------------------------
// Relative timestamp
// ---------------------------------------------------------------------------

/// Relative time for a post ("2h ago", "Yesterday", "3 days ago"), or its
/// date ("Sep 14") once it is a week old, in the app language.
class PostTimestamp extends StatelessWidget {
  final String createdAt;

  /// Fixed "now" for tests; the real clock otherwise.
  final DateTime? now;

  const PostTimestamp({required this.createdAt, this.now, super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPostTimestamp(context, createdAt, now: now),
      style: AppFonts.inter(
        fontSize: 13,
        color: ReaderPalette.of(context).muted,
      ),
    );
  }
}

/// Localized relative time for an ISO-8601 [iso] timestamp.
///
/// Under a minute "Just now", then minutes and hours up to a day, then
/// "Yesterday" for the previous calendar day and "N days ago" within the
/// week. Older posts show the date in the app locale: "Sep 14", with the
/// year once it is not the current one.
String formatPostTimestamp(BuildContext context, String iso, {DateTime? now}) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final date = parsed.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final diff = current.difference(date);

  if (diff.inMinutes < 1) {
    return context.tr(TranslationKeys.communityPostTimeJustNow);
  }
  if (diff.inHours < 1) {
    return context.tr(TranslationKeys.communityPostTimeMinutesAgo,
        {'count': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return context.tr(TranslationKeys.communityPostTimeHoursAgo,
        {'count': '${diff.inHours}'});
  }

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;
  if (days <= 1) return context.tr(TranslationKeys.communityPostTimeYesterday);
  if (days < 7) {
    return context
        .tr(TranslationKeys.communityPostTimeDaysAgo, {'count': '$days'});
  }

  final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  final sameYear = date.year == current.year;
  try {
    return sameYear
        ? DateFormat.MMMd(locale).format(date)
        : DateFormat.yMMMd(locale).format(date);
  } catch (_) {
    // Date symbols for this locale not loaded (no flutter_localizations
    // ancestor, e.g. isolated widgets): fall back to intl's default.
    return sameYear
        ? DateFormat.MMMd().format(date)
        : DateFormat.yMMMd().format(date);
  }
}

// ---------------------------------------------------------------------------
// Post-type chip
// ---------------------------------------------------------------------------

/// Tinted chip naming a post's type ("Prayer", "Study guide"…) with its
/// icon, in the type's own colour. Renders nothing for `'general'` or
/// unknown types.
class PostTypeChip extends StatelessWidget {
  final String postType;

  const PostTypeChip({required this.postType, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    final ({String label, IconData icon})? cfg = switch (postType) {
      'prayer' => (
          label: l10n.postTypePrayer,
          icon: Icons.volunteer_activism_outlined,
        ),
      'praise' => (
          label: l10n.postTypePraise,
          icon: Icons.celebration_outlined,
        ),
      'question' => (
          label: l10n.postTypeQuestion,
          icon: Icons.help_outline_rounded,
        ),
      'study_note' => (
          label: l10n.postTypeStudyNote,
          icon: Icons.edit_note_rounded,
        ),
      'shared_guide' => (
          label: context.tr(TranslationKeys.communityStudyGuideLabel),
          icon: Icons.menu_book_outlined,
        ),
      'daily' => (
          label: l10n.postTypeDaily,
          icon: Icons.menu_book_outlined,
        ),
      _ => null,
    };
    if (cfg == null) return const SizedBox.shrink();
    final color = postTypeAccentColor(postType, isDark: palette.isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 14, color: color),
          const SizedBox(width: 5),
          // Flexible + wrapping: in a narrow header the chip wraps its
          // label rather than overflowing or cutting it.
          Flexible(
            child: Text(
              cfg.label,
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study note: green "On: {lesson}" chip
// ---------------------------------------------------------------------------

class _StudyNoteLink extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final bool isMentor;
  final Color accentColor;

  const _StudyNoteLink({
    required this.post,
    required this.fellowshipId,
    required this.isMentor,
    required this.accentColor,
  });

  /// "On: {lesson title} · Lesson N", falling back to the path name when the
  /// post has no lesson title.
  String _label(BuildContext context) {
    final topic = post.topicTitle?.trim() ?? '';
    final path = post.guideTitle?.trim() ?? '';
    final subject = topic.isNotEmpty ? topic : path;
    final parts = [
      if (subject.isNotEmpty) subject,
      if (post.lessonIndex != null)
        context.tr(TranslationKeys.communitySharedLesson,
            {'number': post.lessonIndex}),
    ];
    return context
        .tr(TranslationKeys.communityPostOnTopic, {'title': parts.join(' · ')});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final canNavigate = post.topicId != null;
    final topic = post.topicTitle?.trim() ?? '';
    final path = post.guideTitle?.trim() ?? '';
    // The learning path's name, shown after the lesson when the chip already
    // leads with the lesson title.
    final pathSuffix = topic.isNotEmpty && path.isNotEmpty ? path : null;

    Future<void> onTap() async {
      if (!canNavigate) return;
      // Open the lesson in the group's language (or this member's choice
      // for the group), never the member's app-wide study language.
      String? groupLanguage;
      try {
        final study = context.read<FellowshipStudyBloc>().state;
        if (study.fellowshipId == fellowshipId) {
          groupLanguage = study.fellowshipLanguage;
        }
      } catch (_) {
        // Not inside a fellowship screen (e.g. Home activity).
      }
      final langCode = await resolveFellowshipLessonLanguage(
        prefs: sl<SharedPreferences>(),
        fellowshipId: fellowshipId,
        fellowshipLanguage: groupLanguage,
        fetchFellowshipLanguage: () async {
          final row = await Supabase.instance.client
              .from('fellowships')
              .select('language')
              .eq('id', fellowshipId)
              .maybeSingle();
          return row?['language'] as String?;
        },
        userStudyLanguage: () async =>
            (await sl<LanguagePreferenceService>().getStudyContentLanguage())
                .code,
      );

      // Fetch the translated path title for the current content language.
      String translatedPathTitle = post.guideTitle ?? '';
      try {
        final joinRow = await Supabase.instance.client
            .from('learning_path_topics')
            .select('learning_path_id')
            .eq('topic_id', post.topicId!)
            .eq('is_active', true)
            .maybeSingle();
        if (joinRow != null) {
          final pathId = joinRow['learning_path_id'] as String;
          final transRow = await Supabase.instance.client
              .from('learning_path_translations')
              .select('title')
              .eq('learning_path_id', pathId)
              .eq('lang_code', langCode)
              .maybeSingle();
          final t = transRow?['title'] as String?;
          if (t != null && t.isNotEmpty) translatedPathTitle = t;
        }
      } catch (_) {
        // Fall back to stored guideTitle
      }

      // The lesson title in the same language the guide is generated in.
      String topicTitle = post.topicTitle ?? '';
      try {
        final topicRow = langCode == 'en'
            ? await Supabase.instance.client
                .from('recommended_topics')
                .select('title')
                .eq('id', post.topicId!)
                .maybeSingle()
            : await Supabase.instance.client
                .from('recommended_topics_translations')
                .select('title')
                .eq('topic_id', post.topicId!)
                .eq('language_code', langCode)
                .maybeSingle();
        final t = topicRow?['title'] as String?;
        if (t != null && t.isNotEmpty) topicTitle = t;
      } catch (_) {
        // Fall back to the post's stored lesson title.
      }

      final topic = LearningPathTopic(
        topicId: post.topicId!,
        title: topicTitle,
        description: '',
        category: post.guideTitle ?? '',
        position: post.lessonIndex != null ? post.lessonIndex! - 1 : 0,
        isMilestone: false,
        xpValue: 0,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FellowshipGuideDetailScreen(
            fellowshipId: fellowshipId,
            topic: topic,
            pathTitle: translatedPathTitle,
            pathDescription: '',
            pathDiscipleLevel: '',
            isMentor: isMentor,
            contentLanguage: langCode,
          ),
        ),
      );
    }

    final radius = BorderRadius.circular(10);
    final textStyle = AppFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: accentColor,
      height: 1.35,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: accentColor.withValues(alpha: palette.isDark ? 0.12 : 0.09),
        borderRadius: radius,
        child: InkWell(
          key: const ValueKey('study-note-chip'),
          onTap: canNavigate ? onTap : null,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 15, color: accentColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _label(context)),
                        if (pathSuffix != null)
                          TextSpan(
                            text: ' · $pathSuffix',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: accentColor.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
                    style: textStyle,
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

// ---------------------------------------------------------------------------
// Shared guide: raised inner card that opens the guide
// ---------------------------------------------------------------------------

/// Tracked label over a shared guide: how it was generated, then its study
/// mode and reading time when the post records them ("Scripture · Standard ·
/// 8 min"). Posts shared before the mode was stored name the guide's
/// language instead ("Topic · English").
String sharedGuideMetaLabel(BuildContext context, FellowshipPostEntity post) {
  final mode = studyModeFromString(post.guideStudyMode);
  return [
    _guideInputTypeLabel(context, post.guideInputType),
    if (mode != null) ...[
      mode.localizedShortName(context),
      mode.localizedDuration(context),
    ] else
      // Each language is named in its own script, so this reads the same
      // whatever the UI language is, in step with [AppLanguage].
      AppLanguage.fromCode(post.guideLanguage ?? AppLanguage.english.code)
          .displayName,
  ].whereType<String>().join(' · ');
}

/// How a guide was generated ("Scripture", "Topic", "Question"), or null for
/// an unknown type.
String? _guideInputTypeLabel(BuildContext context, String? type) {
  switch (type) {
    case 'scripture':
      return context.tr(TranslationKeys.communityPostInputScripture);
    case 'topic':
      return context.tr(TranslationKeys.communityPostInputTopic);
    case 'question':
      return context.tr(TranslationKeys.communityPostInputQuestion);
    default:
      return null;
  }
}

class _SharedGuideLink extends StatefulWidget {
  final FellowshipPostEntity post;

  const _SharedGuideLink({required this.post});

  @override
  State<_SharedGuideLink> createState() => _SharedGuideLinkState();
}

class _SharedGuideLinkState extends State<_SharedGuideLink> {
  bool _loading = false;

  /// Navigates to the study guide.
  ///
  /// First tries to fetch the saved guide by ID from Supabase and pass it as
  /// [existingGuideData] so the screen skips regeneration entirely.
  /// Falls back to navigating with the correct title params so the backend
  /// cache can still be hit.
  Future<void> _navigate() async {
    if (_loading) return;

    final post = widget.post;
    final guideId = post.studyGuideId;
    final inputType = post.guideInputType ?? 'topic';
    final language = post.guideLanguage ?? 'en';
    final title = post.guideTitle ?? '';

    // Attempt to fetch the existing saved guide by ID.
    if (guideId != null && guideId.isNotEmpty) {
      setState(() => _loading = true);
      final data = await fetchSavedGuide(guideId);

      if (!mounted) return;
      setState(() => _loading = false);

      if (data != null) {
        // Full guide data available — load directly, no regeneration.
        context.push(
          '/study-guide'
          '?input=${Uri.encodeComponent(title)}'
          '&type=${Uri.encodeComponent(inputType)}'
          '&language=${Uri.encodeComponent(language)}'
          '&source=fellowship_feed',
          // The row stores the name in `input_value`; the viewer looks for
          // `title`, so without this the heading reads "Study Guide".
          extra: {
            'study_guide': {...data, 'title': title, 'type': inputType},
          },
        );
        return;
      }
    }

    // Fallback: navigate with the correct title params.
    // The backend cache will find the guide by (title + type + language).
    context.push(
      '/study-guide-v2'
      '?input=${Uri.encodeComponent(title)}'
      '&type=${Uri.encodeComponent(inputType)}'
      '&language=${Uri.encodeComponent(language)}'
      '&source=fellowship_feed',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Gold accent: the same colour as the Discipler daily post's guide link,
    // so both read as "open a study guide".
    final accent = palette.accentIcon;
    final post = widget.post;

    final meta = sharedGuideMetaLabel(context, post).toUpperCase();
    final title = post.guideTitle?.trim() ?? '';
    final summary = post.guideSummary?.trim() ?? '';
    final openLabel = context.tr(TranslationKeys.communityPostOpenGuide);

    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: [sharedGuideMetaLabel(context, post), title, summary, openLabel]
          .where((s) => s.isNotEmpty)
          .join(', '),
      excludeSemantics: true,
      child: Material(
        color: palette.isDark ? palette.raised : palette.page,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: accent.withValues(alpha: palette.isDark ? 0.38 : 0.30),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('shared-guide-card'),
          onTap: _loading ? null : _navigate,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.auto_awesome_outlined,
                          size: 14, color: accent),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meta,
                        style: AppFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: accent,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: AppFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                ],
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    key: const ValueKey('shared-guide-summary'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: palette.muted,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        openLabel,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_loading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    else
                      Icon(Icons.arrow_forward_rounded,
                          size: 16, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interactive footer (feed mode): reaction button + replies + share
// ---------------------------------------------------------------------------

/// "1 reply" / "{n} replies", or the plain "Reply" action when there are
/// none yet.
String postRepliesLabel(BuildContext context, int count) {
  if (count <= 0) return AppLocalizations.of(context)!.replyAction;
  if (count == 1) return context.tr(TranslationKeys.communitySharedReplyOne);
  return context.tr(TranslationKeys.communitySharedReplies, {'count': count});
}

/// Reaction, reply and share row shared by the ordinary post card and the
/// daily study card.
///
/// It lives in one place because it did not use to: the daily card kept its
/// own copy, so raising the reaction button to a 44px touch target left its
/// reply button at the old size and the two no longer lined up.
///
/// [leading] is placed first, as the row's primary action (the daily post's
/// "Start study"). With a leading action on a narrow card the replies button
/// and reaction buttons collapse to icon (plus count) so no label is ever truncated; its full
/// label stays in the tooltip and semantics.
class FellowshipPostFooter extends StatelessWidget {
  final FellowshipPostEntity post;
  final Color accentColor;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final Widget? leading;

  /// Below this row width a footer with [leading] shows replies icon-only.
  static const double compactRepliesBelow = 420;

  const FellowshipPostFooter({
    required this.post,
    required this.accentColor,
    required this.onCommentTap,
    this.onShareTap,
    this.leading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return LayoutBuilder(builder: (context, box) {
      final rowWidth =
          box.hasBoundedWidth ? box.maxWidth : MediaQuery.sizeOf(context).width;
      final compactReplies = leading != null && rowWidth < compactRepliesBelow;
      final repliesLabel = postRepliesLabel(context, post.commentCount);
      final replyTextStyle = AppFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: palette.muted,
      );
      final replies = Tooltip(
        message: repliesLabel,
        child: Semantics(
          button: true,
          label: repliesLabel,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('post-footer-replies'),
            onTap: onCommentTap,
            borderRadius: BorderRadius.circular(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compactReplies ? 8 : 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: palette.muted,
                    ),
                    if (!compactReplies) ...[
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(repliesLabel, style: replyTextStyle)),
                    ] else if (post.commentCount > 0) ...[
                      const SizedBox(width: 4),
                      Text('${post.commentCount}', style: replyTextStyle),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final share = IconButton(
        onPressed: onShareTap,
        tooltip: AppLocalizations.of(context)!.sharePost,
        icon: Icon(Icons.share_outlined, size: 20, color: palette.muted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
      final reaction = ConstrainedBox(
        // Capped so a long translated label wraps inside the pill instead
        // of pushing the replies and share buttons off the card.
        constraints: BoxConstraints(maxWidth: rowWidth * 0.45),
        child: FellowshipReactionButton(
          post: post,
          accentColor: accentColor,
        ),
      );
      if (compactReplies) {
        return Row(
          children: [
            // Takes almost all spare width (flex 100 vs the spacer's 1), so
            // the label stays on one line whenever it fits and only wraps,
            // never cuts, on the narrowest cards.
            Flexible(flex: 100, child: leading!),
            const SizedBox(width: 6),
            FellowshipReactionButton(
              post: post,
              accentColor: accentColor,
              compact: true,
            ),
            if (onCommentTap != null) replies,
            const Spacer(),
            if (onShareTap != null) share,
          ],
        );
      }
      return Row(
        children: [
          if (leading != null) ...[
            // Hugs its label; wraps it (never cuts it) past half the row.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: rowWidth * 0.5),
              child: leading,
            ),
            const SizedBox(width: 8),
          ],
          reaction,
          const SizedBox(width: 4),
          if (onCommentTap != null)
            // Expanded + Align: the button still shrinks (and its text
            // wraps) when "replies" runs long in Malayalam/Hindi, but all
            // leftover width goes after it, so share sits at the right edge.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: replies,
              ),
            )
          else
            const Spacer(),
          if (onShareTap != null) share,
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Preview footer (home screen mode): read-only reaction + comment counts
// ---------------------------------------------------------------------------

/// Read-only reaction and reply counts for non-interactive previews.
class FellowshipPostPreviewFooter extends StatelessWidget {
  final FellowshipPostEntity post;

  const FellowshipPostPreviewFooter({required this.post, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final totalReactions = post.reactionCounts.values.fold(0, (a, b) => a + b);
    final style = AppFonts.inter(fontSize: 13, color: palette.muted);

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (totalReactions > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(reactionOptions.first.icon, size: 15, color: palette.muted),
              const SizedBox(width: 4),
              Text('$totalReactions', style: style),
            ],
          ),
        if (post.commentCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 15, color: palette.muted),
              const SizedBox(width: 4),
              Text(postRepliesLabel(context, post.commentCount), style: style),
            ],
          ),
      ],
    );
  }
}
