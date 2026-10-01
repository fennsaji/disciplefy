import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/markdown_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/daily_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

// ============================================================================
// Entry point
// ============================================================================

/// Shows a single guide's info, guide-specific discussion posts, and a
/// comment input.  Opened via Navigator.push from the Lessons tab.
class FellowshipGuideDetailScreen extends StatelessWidget {
  final String fellowshipId;
  final LearningPathTopic topic;
  final String pathTitle;
  final String pathDescription;
  final String pathDiscipleLevel;
  final bool isMentor;
  final String contentLanguage;

  const FellowshipGuideDetailScreen({
    super.key,
    required this.fellowshipId,
    required this.topic,
    required this.pathTitle,
    required this.pathDescription,
    required this.pathDiscipleLevel,
    required this.isMentor,
    this.contentLanguage = 'en',
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return BlocProvider<FellowshipFeedBloc>(
      create: (_) => sl<FellowshipFeedBloc>()
        ..add(FellowshipFeedInitialized(
          isMentor: isMentor,
          currentUserId: currentUserId,
        ))
        ..add(FellowshipFeedLoadRequested(
          fellowshipId: fellowshipId,
          topicId: topic.topicId,
        )),
      child: _GuideDetailContent(
        fellowshipId: fellowshipId,
        topic: topic,
        pathTitle: pathTitle,
        pathDescription: pathDescription,
        pathDiscipleLevel: pathDiscipleLevel,
        contentLanguage: contentLanguage,
      ),
    );
  }
}

/// Study-guide route for a fellowship lesson. [language] must be the
/// fellowship's content language (the one the lesson title is shown in), so
/// the generated guide matches the lesson.
@visibleForTesting
String fellowshipStudyGuideLocation({
  required LearningPathTopic topic,
  required String language,
  required StudyMode studyMode,
  String pathTitle = '',
  String pathDescription = '',
  String pathDiscipleLevel = '',
}) {
  final encodedTitle = Uri.encodeComponent(topic.title);
  final inputType = topic.inputType.isNotEmpty ? topic.inputType : 'topic';
  final topicIdParam =
      topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
  final descParam = topic.description.isNotEmpty
      ? '&description=${Uri.encodeComponent(topic.description)}'
      : '';
  final pathTitleParam = pathTitle.isNotEmpty
      ? '&path_title=${Uri.encodeComponent(pathTitle)}'
      : '';
  final pathDescParam = pathDescription.isNotEmpty
      ? '&path_description=${Uri.encodeComponent(pathDescription)}'
      : '';
  final discipleLevelParam = pathDiscipleLevel.isNotEmpty
      ? '&disciple_level=${Uri.encodeComponent(pathDiscipleLevel)}'
      : '';
  return '/study-guide-v2?input=$encodedTitle&type=$inputType&language=$language&mode=${studyMode.name}&source=fellowship'
      '$topicIdParam$descParam$pathTitleParam$pathDescParam$discipleLevelParam';
}

// ============================================================================
// Main content
// ============================================================================

class _GuideDetailContent extends StatefulWidget {
  final String fellowshipId;
  final LearningPathTopic topic;
  final String pathTitle;
  final String pathDescription;
  final String pathDiscipleLevel;
  final String contentLanguage;

  const _GuideDetailContent({
    required this.fellowshipId,
    required this.topic,
    required this.pathTitle,
    required this.pathDescription,
    required this.pathDiscipleLevel,
    required this.contentLanguage,
  });

  @override
  State<_GuideDetailContent> createState() => _GuideDetailContentState();
}

class _GuideDetailContentState extends State<_GuideDetailContent> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isOpeningStudyGuide = false;

  /// Lazily resolved topic — populated when widget.topic.description is empty.
  LearningPathTopic? _resolvedTopic;

  /// Effective topic: resolved (with description) if available, else original.
  LearningPathTopic get _topic => _resolvedTopic ?? widget.topic;

  @override
  void initState() {
    super.initState();
    if (widget.topic.description.isEmpty && widget.topic.topicId.isNotEmpty) {
      _fetchTopicDescription();
    }
  }

  Future<void> _fetchTopicDescription() async {
    try {
      final row = await Supabase.instance.client
          .from('recommended_topics')
          .select('description')
          .eq('id', widget.topic.topicId)
          .single();
      final desc = (row['description'] as String?)?.trim() ?? '';
      if (desc.isNotEmpty && mounted) {
        setState(() {
          _resolvedTopic = LearningPathTopic(
            topicId: widget.topic.topicId,
            title: widget.topic.title,
            description: desc,
            category: widget.topic.category,
            position: widget.topic.position,
            isMilestone: widget.topic.isMilestone,
            inputType: widget.topic.inputType,
            xpValue: widget.topic.xpValue,
            isCompleted: widget.topic.isCompleted,
            isInProgress: widget.topic.isInProgress,
          );
        });
      }
    } catch (_) {
      // Silently ignore — description section simply stays hidden
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitPost() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<FellowshipFeedBloc>().add(
          FellowshipPostCreateRequested(
            fellowshipId: widget.fellowshipId,
            content: text,
            postType: 'study_note',
            topicId: _topic.topicId,
            topicTitle: _topic.title,
            guideTitle: widget.pathTitle,
            lessonIndex: _topic.position + 1,
          ),
        );
    _controller.clear();
    _focusNode.unfocus();
  }

  Future<void> _openStudyGuide() async {
    if (_isOpeningStudyGuide) return;
    setState(() => _isOpeningStudyGuide = true);

    try {
      final topic = _topic;

      // The lesson is shown in the fellowship's language, so the guide must be
      // generated in that same language — not the member's own study language.
      final languageService = sl<LanguagePreferenceService>();
      final language = widget.contentLanguage;
      final studyMode =
          await languageService.getStudyModePreference() ?? StudyMode.standard;

      if (!mounted) return;

      await context.push(fellowshipStudyGuideLocation(
        topic: topic,
        language: language,
        studyMode: studyMode,
        pathTitle: widget.pathTitle,
        pathDescription: widget.pathDescription,
        pathDiscipleLevel: widget.pathDiscipleLevel,
      ));
    } finally {
      if (mounted) setState(() => _isOpeningStudyGuide = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(title: _topic.title, background: palette.page),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Guide info card + Open button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _GuideInfoCard(
                      topic: _topic,
                      pathTitle: widget.pathTitle,
                      isLoading: _isOpeningStudyGuide,
                      onOpenStudyGuide: _openStudyGuide,
                    ),
                  ),
                ),

                // Discussion header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommunitySectionHeader(
                          title: context
                              .tr(TranslationKeys.communityPagesDiscussion),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(
                              TranslationKeys.communityPagesDiscussionSubtitle),
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Posts list
                BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                  builder: (ctx, feedState) {
                    if (feedState.status == FellowshipFeedStatus.loading) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    if (feedState.posts.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 40, horizontal: 32),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 40, color: palette.dim),
                              const SizedBox(height: 12),
                              Text(
                                context.tr(TranslationKeys
                                    .communityPagesDiscussionEmpty),
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(
                                  color: palette.muted,
                                  fontSize: 14.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PostCard(post: feedState.posts[i]),
                          ),
                          childCount: feedState.posts.length,
                        ),
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // Bottom comment input
          _CommentInputBar(
            controller: _controller,
            focusNode: _focusNode,
            onSubmit: _submitPost,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Guide info card
// ============================================================================

class _GuideInfoCard extends StatelessWidget {
  final LearningPathTopic topic;
  final String pathTitle;
  final bool isLoading;
  final VoidCallback onOpenStudyGuide;

  const _GuideInfoCard({
    required this.topic,
    required this.pathTitle,
    required this.onOpenStudyGuide,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gold = SettingsToneColors.of(context, SettingsTone.gold);

    return CommunityFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${topic.position + 1}',
                  style: AppFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pathTitle.isNotEmpty) ...[
                      CommunitySectionLabel(pathTitle, fontSize: 11),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      topic.title,
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    if (topic.isMilestone) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: gold.fill,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flag_rounded,
                                size: 13, color: gold.foreground),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                context.tr(
                                    TranslationKeys.communityPagesMilestone),
                                style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: gold.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (topic.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              topic.description,
              style: AppFonts.inter(
                color: palette.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          CommunityWideCta(
            label: context.tr(TranslationKeys.communityPagesOpenGuide),
            icon: Icons.menu_book_rounded,
            loading: isLoading,
            onPressed: onOpenStudyGuide,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Post card (thread style)
// ============================================================================

class _PostCard extends StatefulWidget {
  final FellowshipPostEntity post;

  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final isSystem = post.authorIsSystem;

    return CommunityFormCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSystem)
                const DisciplerAvatar(radius: 18)
              else
                MemberAvatar(
                  displayName: post.authorDisplayName,
                  avatarUrl: post.authorAvatarUrl,
                  radius: 18,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorLine(
                      name: isSystem
                          ? l10n.disciplerName
                          : post.authorDisplayName,
                      isSystem: isSystem,
                      createdAt: post.createdAt,
                      fontSize: 14.5,
                    ),
                    const SizedBox(height: 6),
                    if (post.isDaily)
                      DailyPostBody(
                        content: post.content,
                        accent: dailyPostAccent(context),
                      )
                    else
                      Text(
                        isSystem
                            ? stripEmphasisMarkers(post.content)
                            : post.content,
                        style: AppFonts.inter(
                          color: palette.text,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    if (isSystem) ...[
                      const SizedBox(height: 8),
                      const DisciplerFooterNote(),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Reply toggle
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: TextButton(
              onPressed: () {
                setState(() => _showReplies = !_showReplies);
                if (_showReplies) {
                  context.read<FellowshipFeedBloc>().add(
                        FellowshipCommentsOpenRequested(postId: post.id),
                      );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: palette.muted,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      postRepliesLabel(context, post.commentCount),
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (post.commentCount > 0) ...[
                    const SizedBox(width: 2),
                    Icon(
                      _showReplies
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded replies + inline reply input
          if (_showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                builder: (ctx, feedState) {
                  final isActive = feedState.activePostId == post.id;
                  final loading = isActive &&
                      feedState.commentsStatus ==
                          FellowshipCommentsStatus.loading;
                  final comments = isActive
                      ? feedState.comments
                      : const <FellowshipCommentEntity>[];

                  if (loading) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...comments.map((c) => _CommentRow(comment: c)),
                      _InlineReplyInput(
                        onSubmit: (text) {
                          context.read<FellowshipFeedBloc>()
                            ..add(FellowshipCommentsOpenRequested(
                                postId: post.id))
                            ..add(FellowshipCommentCreateRequested(
                                content: text));
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Name (+ Discipler AI chip) and relative time, wrapping on narrow widths.
class _AuthorLine extends StatelessWidget {
  final String name;
  final bool isSystem;
  final String createdAt;
  final double fontSize;

  const _AuthorLine({
    required this.name,
    required this.isSystem,
    required this.createdAt,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          name,
          style: AppFonts.inter(
            color: palette.text,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isSystem) const DisciplerAiChip(),
        PostTimestamp(createdAt: createdAt),
      ],
    );
  }
}

// ============================================================================
// Comment row
// ============================================================================

class _CommentRow extends StatelessWidget {
  final FellowshipCommentEntity comment;
  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final isSystem = comment.authorIsSystem;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSystem)
            const DisciplerAvatar(radius: 14)
          else
            MemberAvatar(
              displayName: comment.authorDisplayName,
              avatarUrl: comment.authorAvatarUrl,
              radius: 14,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorLine(
                  name:
                      isSystem ? l10n.disciplerName : comment.authorDisplayName,
                  isSystem: isSystem,
                  createdAt: comment.createdAt,
                  fontSize: 13.5,
                ),
                const SizedBox(height: 3),
                Text(
                  isSystem
                      ? stripEmphasisMarkers(comment.content)
                      : comment.content,
                  style: AppFonts.inter(
                    color: palette.text,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (isSystem) ...[
                  const SizedBox(height: 6),
                  const DisciplerFooterNote(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Round send button + inline reply input
// ============================================================================

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const _SendButton({required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr(TranslationKeys.communityPagesSend),
      child: Material(
        color: ReaderPalette.selectedFill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.send_rounded,
                size: size * 0.42, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _InlineReplyInput extends StatefulWidget {
  final void Function(String text) onSubmit;
  const _InlineReplyInput({required this.onSubmit});

  @override
  State<_InlineReplyInput> createState() => _InlineReplyInputState();
}

class _InlineReplyInputState extends State<_InlineReplyInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: AppFonts.inter(color: palette.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: context.tr(TranslationKeys.communityPagesReplyHint),
                hintStyle: AppFonts.inter(color: palette.dim, fontSize: 14),
                isDense: true,
                filled: true,
                fillColor: communityWellFill(palette),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(onTap: _send, size: 40),
        ],
      ),
    );
  }
}

// ============================================================================
// Bottom comment input bar
// ============================================================================

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
      buildWhen: (p, c) => p.submitting != c.submitting,
      builder: (ctx, state) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 12,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                10,
          ),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: AppFonts.inter(color: palette.text, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: context
                        .tr(TranslationKeys.communityPagesReflectionHint),
                    hintStyle: AppFonts.inter(color: palette.dim, fontSize: 15),
                    filled: true,
                    fillColor: palette.raised,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (state.submitting)
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                _SendButton(onTap: onSubmit),
            ],
          ),
        );
      },
    );
  }
}
