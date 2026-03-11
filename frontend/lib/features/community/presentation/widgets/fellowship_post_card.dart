import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/study_topics/domain/entities/learning_path.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../screens/fellowship_guide_detail_screen.dart';

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

  const FellowshipPostCard({
    required this.post,
    required this.fellowshipId,
    this.isMentor = false,
    this.currentUserId,
    this.interactive = true,
    this.maxContentLines,
    this.onCommentTap,
    this.onReportTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = postTypeAccentColor(post.postType, isDark: isDark);

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
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
                _PostAvatar(
                  displayName: post.authorDisplayName,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorDisplayName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      }
                    },
                    itemBuilder: (_) => [
                      if (isMentor || post.authorUserId == currentUserId)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              const Text('Delete',
                                  style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      if (!isMentor && post.authorUserId != currentUserId)
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  color: context.appTextSecondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.reportTitle,
                                style: TextStyle(color: context.appTextPrimary),
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
                child: Text(
                  post.content,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    color: context.appTextPrimary,
                    height: 1.65,
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

            const SizedBox(height: 14),

            // ── Footer ─────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(right: interactive ? 8 : 0),
              child: interactive
                  ? _InteractiveFooter(
                      post: post,
                      accentColor: accentColor,
                      onCommentTap: onCommentTap,
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
    default:
      return AppColors.brandPrimary;
  }
}

// ---------------------------------------------------------------------------
// Author avatar
// ---------------------------------------------------------------------------

class _PostAvatar extends StatelessWidget {
  final String displayName;
  final Color accentColor;

  const _PostAvatar({required this.displayName, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: accentColor.withAlpha(36),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
      ),
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

    void onTap() {
      if (!canNavigate) return;
      final topic = LearningPathTopic(
        topicId: post.topicId!,
        title: post.topicTitle ?? '',
        description: '',
        category: post.guideTitle ?? '',
        position: post.lessonIndex != null ? post.lessonIndex! - 1 : 0,
        isMilestone: false,
        xpValue: 0,
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FellowshipGuideDetailScreen(
            fellowshipId: fellowshipId,
            topic: topic,
            pathTitle: post.guideTitle ?? '',
            pathDescription: '',
            pathDiscipleLevel: '',
            isMentor: isMentor,
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
      try {
        final data = await Supabase.instance.client
            .from('study_guides')
            .select()
            .eq('id', guideId)
            .maybeSingle();

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
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        // Fall through to param-based navigation below.
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

  const _InteractiveFooter({
    required this.post,
    required this.accentColor,
    required this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReactionButton(post: post, accentColor: accentColor),
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
                    post.commentCount > 0 ? '${post.commentCount}' : 'Reply',
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

// ---------------------------------------------------------------------------
// Reaction button (tap = toggle amen, long-press = emoji picker)
// ---------------------------------------------------------------------------

class _ReactionButton extends StatefulWidget {
  final FellowshipPostEntity post;
  final Color accentColor;

  const _ReactionButton({
    required this.post,
    required this.accentColor,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  OverlayEntry? _pickerOverlay;

  static const _kReactions = [
    (type: 'amen', emoji: '🙏'),
    (type: 'i_prayed', emoji: '🕊️'),
    (type: 'heart', emoji: '❤️'),
    (type: 'fire', emoji: '🔥'),
    (type: 'hands', emoji: '👐'),
  ];

  /// Default reaction (emoji + type + label) based on post type.
  static ({String type, String emoji, String label}) _defaultForType(
      String postType) {
    switch (postType) {
      case 'praise':
        return (type: 'amen', emoji: '🙏', label: 'Amen');
      case 'prayer':
        return (type: 'i_prayed', emoji: '🕊️', label: 'I Prayed');
      case 'question':
        return (type: 'heart', emoji: '❤️', label: 'Love');
      case 'study_note':
      case 'shared_guide':
        return (type: 'fire', emoji: '🔥', label: 'Fire');
      default: // general
        return (type: 'amen', emoji: '🙏', label: 'Amen');
    }
  }

  int get _totalCount =>
      widget.post.reactionCounts.values.fold(0, (s, c) => s + c);

  String get _activeEmoji {
    final active = widget.post.userReaction;
    if (active == null) return _defaultForType(widget.post.postType).emoji;
    return _kReactions
        .firstWhere((r) => r.type == active, orElse: () => _kReactions.first)
        .emoji;
  }

  void _onTap() {
    final type =
        widget.post.userReaction ?? _defaultForType(widget.post.postType).type;
    context.read<FellowshipFeedBloc>().add(
          FellowshipReactionToggleRequested(
            postId: widget.post.id,
            reactionType: type,
          ),
        );
  }

  void _showPicker(Offset globalPosition) {
    final bloc = context.read<FellowshipFeedBloc>();
    _pickerOverlay = OverlayEntry(
      builder: (_) => _ReactionPickerOverlay(
        postId: widget.post.id,
        bloc: bloc,
        reactions: _kReactions,
        tapPosition: globalPosition,
        userReaction: widget.post.userReaction,
        onDismiss: _removePicker,
      ),
    );
    Overlay.of(context).insert(_pickerOverlay!);
  }

  void _removePicker() {
    _pickerOverlay?.remove();
    _pickerOverlay = null;
  }

  @override
  void dispose() {
    _removePicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalCount;
    final isActive = widget.post.userReaction != null;
    return GestureDetector(
      onTap: _onTap,
      onLongPressStart: (d) => _showPicker(d.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? widget.accentColor.withAlpha(26)
              : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? widget.accentColor.withAlpha(102)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_activeEmoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              total > 0
                  ? '$total'
                  : _defaultForType(widget.post.postType).label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? widget.accentColor : context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction picker overlay (long-press, Facebook-style)
// ---------------------------------------------------------------------------

class _ReactionPickerOverlay extends StatefulWidget {
  final String postId;
  final FellowshipFeedBloc bloc;
  final List<({String type, String emoji})> reactions;
  final Offset tapPosition;
  final String? userReaction;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.postId,
    required this.bloc,
    required this.reactions,
    required this.tapPosition,
    required this.userReaction,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _select(String type) {
    widget.bloc.add(FellowshipReactionToggleRequested(
      postId: widget.postId,
      reactionType: type,
    ));
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    const pickerWidth = 5 * 48.0 + 16.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final left = (widget.tapPosition.dx - pickerWidth / 2)
        .clamp(8.0, screenWidth - pickerWidth - 8);
    final top = (widget.tapPosition.dy - 72).clamp(
      MediaQuery.of(context).padding.top + 8,
      double.infinity,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(32),
              color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
              shadowColor: Colors.black38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.reactions.map((r) {
                    final isActive = widget.userReaction == r.type;
                    return GestureDetector(
                      onTap: () => _select(r.type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: isActive
                            ? BoxDecoration(
                                color: AppColors.brandPrimary.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              )
                            : null,
                        child: Text(
                          r.emoji,
                          style: TextStyle(
                            fontSize: isActive ? 26 : 22,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
