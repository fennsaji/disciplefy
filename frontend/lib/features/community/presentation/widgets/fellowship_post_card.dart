import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/discipler.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/study_topics/domain/entities/learning_path.dart';
import '../../data/services/saved_guide_fetcher.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../screens/fellowship_guide_detail_screen.dart';
import 'daily_post_card.dart';
import 'discipler_badges.dart';
import 'reaction_button.dart';

/// Regex matching a mention token like `@Discipler` or `@Jane.Doe` in post
/// or comment content.
final RegExp _mentionRegex = RegExp(r'(@[A-Za-z][\w.]*)');

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

/// Returns the popup menu item keys to show for [post], in display order.
///
/// - `'share'` is always present.
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
  final items = <String>['share'];
  final own = post.authorUserId == currentUserId;
  if (isMentor || isAdmin || own) items.add('delete');
  if (post.authorIsSystem) return items;
  if (!isMentor && !own) items.add('report');
  if (!own) items.add('block');
  return items;
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
/// Use [maxContentLines] to truncate content for preview contexts.
class FellowshipPostCard extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  /// Whether this card has interactive reaction/reply buttons.
  /// Set to `false` for the Recent Activity preview.
  final bool interactive;

  /// Truncates the content text. `null` = no limit.
  final int? maxContentLines;

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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (post.isDaily) {
      return DailyPostCard(
        post: post,
        fellowshipId: fellowshipId,
        onCommentTap: onCommentTap,
        onShareTap: onShareTap,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = postTypeAccentColor(post.postType, isDark: isDark);
    final isSystem = post.authorIsSystem;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isSystem
            ? context.appPrimary.withAlpha(isDark ? 40 : 18)
            : context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appBorder.withAlpha(50),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, interactive ? 8 : 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isSystem
                    ? const DisciplerAvatar()
                    : _PostAvatar(
                        displayName: post.authorDisplayName,
                        accentColor: accentColor,
                        avatarUrl: post.authorAvatarUrl,
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isSystem
                                  ? l10n.disciplerName
                                  : post.authorDisplayName,
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
                          if (isSystem) ...[
                            const SizedBox(width: 6),
                            const DisciplerAiChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _PostTimestamp(createdAt: post.createdAt),
                          if (post.postType != 'general') ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ),
                            _PostTypeLabel(postType: post.postType),
                          ],
                          if (post.toMentors) ...[
                            const SizedBox(width: 6),
                            _ToMentorsChip(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Overflow menu — interactive mode only
                if (interactive)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: context.appTextTertiary,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
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
                      for (final item in postMenuItems(
                        post,
                        isMentor: isMentor,
                        isAdmin: isAdmin,
                        currentUserId: currentUserId,
                      ))
                        if (item == 'share')
                          PopupMenuItem<String>(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined,
                                    color: context.appTextSecondary, size: 20),
                                const SizedBox(width: 8),
                                Text(l10n.sharePost,
                                    style: TextStyle(
                                        color: context.appTextPrimary)),
                              ],
                            ),
                          )
                        else if (item == 'delete')
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    color: context.appError, size: 20),
                                const SizedBox(width: 8),
                                Text(l10n.deleteAction,
                                    style: TextStyle(color: context.appError)),
                              ],
                            ),
                          )
                        else if (item == 'report')
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined,
                                    color: context.appTextSecondary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.reportTitle,
                                  style:
                                      TextStyle(color: context.appTextPrimary),
                                ),
                              ],
                            ),
                          )
                        else if (item == 'block')
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(Icons.block,
                                    color: context.appError, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.blockUserTitle,
                                  style: TextStyle(color: context.appError),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Content ────────────────────────────────────────────────────
            if (post.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: interactive ? 8 : 0),
                child: Text.rich(
                  TextSpan(
                    children: mentionSpans(
                      post.content,
                      TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        color: context.appTextPrimary,
                        height: 1.65,
                      ),
                      TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.appPrimary,
                        height: 1.65,
                      ),
                    ),
                  ),
                  maxLines: maxContentLines,
                  overflow: maxContentLines != null
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
              ),

            // ── study_note link preview ─────────────────────────────────
            if (post.postType == 'study_note' &&
                (post.topicId != null || post.guideTitle != null)) ...[
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(right: interactive ? 8 : 0),
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
                padding: EdgeInsets.only(right: interactive ? 8 : 0),
                child: _SharedGuideLink(post: post, accentColor: accentColor),
              ),
            ],

            if (isSystem) ...[
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(right: interactive ? 8 : 0),
                child: const DisciplerFooterNote(),
              ),
            ],

            const SizedBox(height: 14),

            // ── Footer ─────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(right: interactive ? 8 : 0),
              child: interactive
                  ? _InteractiveFooter(
                      post: post,
                      accentColor: accentColor,
                      onCommentTap: onCommentTap,
                      onShareTap: onShareTap,
                    )
                  : _PreviewFooter(post: post),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accent color helper (shared across widgets)
// ---------------------------------------------------------------------------

Color postTypeAccentColor(String postType, {bool isDark = false}) {
  if (isDark) {
    switch (postType) {
      case 'prayer':
        return AppColors.infoLighter;
      case 'praise':
        return AppColors.warningLighter;
      case 'question':
        return AppColors.successLighter;
      case 'study_note':
        return const Color(0xFFFFCC02);
      case 'shared_guide':
        return const Color(0xFF4DD0E1);
      case 'daily':
        return AppColors.brandHighlightDark;
      default:
        return AppColors.brandPrimaryLight;
    }
  }
  switch (postType) {
    case 'prayer':
      return AppColors.info;
    case 'praise':
      return AppColors.warning;
    case 'question':
      return AppColors.success;
    case 'study_note':
      return const Color(0xFF8B6914);
    case 'shared_guide':
      return const Color(0xFF1B7A7A);
    case 'daily':
      return AppColors.brandHighlightDark;
    default:
      return AppColors.brandPrimary;
  }
}

// ---------------------------------------------------------------------------
// "To mentors" chip
// ---------------------------------------------------------------------------

class _ToMentorsChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.brandHighlight.withAlpha(isDark ? 60 : 255),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AppLocalizations.of(context)!.toMentorsChip,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.brandHighlightDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Author avatar
// ---------------------------------------------------------------------------

class _PostAvatar extends StatelessWidget {
  final String displayName;
  final Color accentColor;
  final String? avatarUrl;

  const _PostAvatar({
    required this.displayName,
    required this.accentColor,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: accentColor.withAlpha(36),
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Relative timestamp
// ---------------------------------------------------------------------------

class _PostTimestamp extends StatelessWidget {
  final String createdAt;

  const _PostTimestamp({required this.createdAt});

  String _format(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(createdAt),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: context.appTextTertiary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-type inline label (no background pill)
// ---------------------------------------------------------------------------

class _PostTypeLabel extends StatelessWidget {
  final String postType;

  const _PostTypeLabel({required this.postType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, ({String label, Color color})> config = {
      'prayer': (
        label: l10n.postTypePrayer,
        color: isDark ? AppColors.infoLighter : AppColors.infoDark,
      ),
      'praise': (
        label: l10n.postTypePraise,
        color: isDark ? AppColors.warningLighter : AppColors.warningDark,
      ),
      'question': (
        label: l10n.postTypeQuestion,
        color: isDark ? AppColors.successLighter : AppColors.successDark,
      ),
      'study_note': (
        label: l10n.postTypeStudyNote,
        color: isDark ? const Color(0xFFFFCC02) : const Color(0xFF8B6914),
      ),
      'shared_guide': (
        label: l10n.postTypeSharedGuide,
        color: isDark ? const Color(0xFF4DD0E1) : const Color(0xFF1B7A7A),
      ),
      'daily': (
        label: l10n.postTypeDaily,
        color: AppColors.brandHighlightDark,
      ),
    };

    final cfg = config[postType];
    if (cfg == null) return const SizedBox.shrink();

    return Text(
      cfg.label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: cfg.color,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study note link preview (context + CTA — single tappable block)
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = accentColor.withAlpha(isDark ? 55 : 45);
    final bgColor = accentColor.withAlpha(isDark ? 18 : 10);
    final canNavigate = post.topicId != null;

    Future<void> onTap() async {
      if (!canNavigate) return;
      final lang =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();

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
              .eq('lang_code', lang.code)
              .maybeSingle();
          final t = transRow?['title'] as String?;
          if (t != null && t.isNotEmpty) translatedPathTitle = t;
        }
      } catch (_) {
        // Fall back to stored guideTitle
      }

      final topic = LearningPathTopic(
        topicId: post.topicId!,
        title: post.topicTitle ?? '',
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
            contentLanguage: lang.code,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: canNavigate ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 16, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.guideTitle != null && post.guideTitle!.isNotEmpty)
                    Text(
                      post.guideTitle!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: accentColor.withAlpha(isDark ? 200 : 180),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (post.topicTitle != null || post.lessonIndex != null)
                    Padding(
                      padding: EdgeInsets.only(
                        top: (post.guideTitle != null &&
                                post.guideTitle!.isNotEmpty)
                            ? 2
                            : 0,
                      ),
                      child: Text(
                        [
                          if (post.lessonIndex != null)
                            'Lesson ${post.lessonIndex}',
                          if (post.topicTitle != null &&
                              post.topicTitle!.isNotEmpty)
                            post.topicTitle!,
                        ].join(' · '),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (canNavigate) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: accentColor.withAlpha(160),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared guide link preview (context + CTA — single tappable block)
// ---------------------------------------------------------------------------

class _SharedGuideLink extends StatefulWidget {
  final FellowshipPostEntity post;
  final Color accentColor;

  const _SharedGuideLink({
    required this.post,
    required this.accentColor,
  });

  @override
  State<_SharedGuideLink> createState() => _SharedGuideLinkState();
}

class _SharedGuideLinkState extends State<_SharedGuideLink> {
  bool _loading = false;

  String _inputTypeLabel(String? type) {
    switch (type) {
      case 'scripture':
        return 'Verse study';
      case 'topic':
        return 'Topic study';
      default:
        return 'Study guide';
    }
  }

  String _languageLabel(String? lang) {
    switch (lang) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return lang ?? 'English';
    }
  }

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
          extra: {'study_guide': data},
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.accentColor;
    final borderColor = accentColor.withAlpha(isDark ? 55 : 45);
    final bgColor = accentColor.withAlpha(isDark ? 18 : 10);

    final meta = [
      _inputTypeLabel(widget.post.guideInputType),
      _languageLabel(widget.post.guideLanguage),
    ].join(' · ');

    return GestureDetector(
      onTap: _loading ? null : _navigate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Icon(Icons.auto_stories_rounded,
                    size: 16, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accentColor.withAlpha(isDark ? 200 : 180),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.post.guideTitle != null &&
                      widget.post.guideTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.post.guideTitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: accentColor.withAlpha(160),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interactive footer (feed mode): reaction button + comment button
// ---------------------------------------------------------------------------

class _InteractiveFooter extends StatelessWidget {
  final FellowshipPostEntity post;
  final Color accentColor;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  const _InteractiveFooter({
    required this.post,
    required this.accentColor,
    required this.onCommentTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        FellowshipReactionButton(post: post, accentColor: accentColor),
        const SizedBox(width: 8),
        if (onCommentTap != null)
          GestureDetector(
            onTap: onCommentTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.appSurfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 14,
                    color: context.appTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.commentCount > 0
                        ? '${post.commentCount}'
                        : l10n.replyAction,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        if (onShareTap != null)
          IconButton(
            onPressed: onShareTap,
            icon: Icon(Icons.share_outlined,
                size: 18, color: context.appTextSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preview footer (home screen mode): read-only reaction + comment counts
// ---------------------------------------------------------------------------

class _PreviewFooter extends StatelessWidget {
  final FellowshipPostEntity post;

  const _PreviewFooter({required this.post});

  @override
  Widget build(BuildContext context) {
    final totalReactions = post.reactionCounts.values.fold(0, (a, b) => a + b);

    return Row(
      children: [
        if (totalReactions > 0) ...[
          const Text('🙏', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$totalReactions',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(width: 14),
        ],
        if (post.commentCount > 0) ...[
          Icon(Icons.chat_bubble_outline_rounded,
              size: 14, color: context.appTextTertiary),
          const SizedBox(width: 4),
          Text(
            '${post.commentCount}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
