import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/study_topics/domain/entities/learning_path.dart';
import '../../domain/entities/fellowship_comment_entity.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';

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

  void _openStudyGuide() {
    final topic = _topic;
    final encodedTitle = Uri.encodeComponent(topic.title);
    final topicIdParam =
        topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
    final descParam = topic.description.isNotEmpty
        ? '&description=${Uri.encodeComponent(topic.description)}'
        : '';
    final pathTitleParam = widget.pathTitle.isNotEmpty
        ? '&path_title=${Uri.encodeComponent(widget.pathTitle)}'
        : '';
    final pathDescParam = widget.pathDescription.isNotEmpty
        ? '&path_description=${Uri.encodeComponent(widget.pathDescription)}'
        : '';
    final discipleLevelParam = widget.pathDiscipleLevel.isNotEmpty
        ? '&disciple_level=${Uri.encodeComponent(widget.pathDiscipleLevel)}'
        : '';
    context.push(
      '/study-guide-v2?input=$encodedTitle&type=topic&language=${widget.contentLanguage}&mode=standard&source=fellowship'
      '$topicIdParam$descParam$pathTitleParam$pathDescParam$discipleLevelParam',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        title: Text(
          _topic.title,
          style: TextStyle(
            color: context.appTextPrimary,
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: context.appTextPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Guide info card + Open button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _GuideInfoCard(
                      topic: _topic,
                      pathTitle: widget.pathTitle,
                      isDark: isDark,
                      onOpenStudyGuide: _openStudyGuide,
                    ),
                  ),
                ),

                // Discussion header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discussion',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Share your reflections on this lesson',
                          style: TextStyle(
                            color: context.appTextTertiary,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Divider(height: 1, color: context.appDivider),
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
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 40, color: context.appTextTertiary),
                                const SizedBox(height: 12),
                                Text(
                                  'No discussion yet.\nBe the first to share!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.appTextTertiary,
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _PostCard(
                          post: feedState.posts[i],
                          isDark: isDark,
                        ),
                        childCount: feedState.posts.length,
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
            isDark: isDark,
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
  final bool isDark;
  final VoidCallback onOpenStudyGuide;

  const _GuideInfoCard({
    required this.topic,
    required this.pathTitle,
    required this.isDark,
    required this.onOpenStudyGuide,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = isDark
        ? AppColors.brandPrimaryLight
        : Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guide header row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${topic.position + 1}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: brandColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pathTitle,
                        style: TextStyle(
                          color: context.appTextTertiary,
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (topic.isMilestone)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag,
                            size: 12, color: AppColors.warningDark),
                        const SizedBox(width: 4),
                        Text(
                          'Milestone',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (topic.description.isNotEmpty) ...[
            Divider(height: 1, color: context.appDivider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                topic.description,
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],

          Divider(height: 1, color: context.appDivider),

          // Open Study Guide button
          InkWell(
            onTap: onOpenStudyGuide,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 18, color: brandColor),
                  const SizedBox(width: 8),
                  Text(
                    'Open Study Guide',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: brandColor),
                ],
              ),
            ),
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
  final bool isDark;

  const _PostCard({required this.post, required this.isDark});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(displayName: post.authorDisplayName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author + time
                    Row(
                      children: [
                        Text(
                          post.authorDisplayName,
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '·',
                          style: TextStyle(
                              color: context.appTextTertiary, fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(post.createdAt),
                          style: TextStyle(
                            color: context.appTextTertiary,
                            fontFamily: 'Inter',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Content
                    Text(
                      post.content,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Reply action
                    GestureDetector(
                      onTap: () {
                        setState(() => _showReplies = !_showReplies);
                        if (_showReplies) {
                          context.read<FellowshipFeedBloc>().add(
                                FellowshipCommentsOpenRequested(
                                    postId: post.id),
                              );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.commentCount > 0
                                ? '${post.commentCount} ${post.commentCount == 1 ? 'reply' : 'replies'}'
                                : 'Reply',
                            style: TextStyle(
                              color: context.appTextTertiary,
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                          ),
                          if (post.commentCount > 0) ...[
                            const SizedBox(width: 2),
                            Icon(
                              _showReplies
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: context.appTextTertiary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expanded replies + inline reply input
        if (_showReplies)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
              builder: (ctx, feedState) {
                final isActive = feedState.activePostId == post.id;
                final loading = isActive &&
                    feedState.commentsStatus ==
                        FellowshipCommentsStatus.loading;
                final comments =
                    isActive ? feedState.comments : const <dynamic>[];

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
                      isDark: widget.isDark,
                      onSubmit: (text) {
                        context.read<FellowshipFeedBloc>()
                          ..add(
                              FellowshipCommentsOpenRequested(postId: post.id))
                          ..add(
                              FellowshipCommentCreateRequested(content: text));
                      },
                    ),
                  ],
                );
              },
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: context.appDivider),
        ),
      ],
    );
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
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
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(displayName: comment.authorDisplayName, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorDisplayName,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: TextStyle(
                          color: context.appTextTertiary, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        color: context.appTextTertiary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ============================================================================
// Inline reply input
// ============================================================================

class _InlineReplyInput extends StatefulWidget {
  final bool isDark;
  final void Function(String text) onSubmit;
  const _InlineReplyInput({required this.isDark, required this.onSubmit});

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(
                  color: context.appTextPrimary,
                  fontFamily: 'Inter',
                  fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add a reply…',
                hintStyle: TextStyle(
                    color: context.appTextTertiary,
                    fontFamily: 'Inter',
                    fontSize: 13),
                isDense: true,
                filled: true,
                fillColor: context.appInputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _ctrl.text.trim();
              if (text.isEmpty) return;
              widget.onSubmit(text);
              _ctrl.clear();
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: context.appInteractive,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
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
  final bool isDark;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
      buildWhen: (p, c) => p.submitting != c.submitting,
      builder: (ctx, state) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: context.appSurface,
            border: Border(top: BorderSide(color: context.appBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontFamily: 'Inter',
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your reflection…',
                    hintStyle: TextStyle(
                        color: context.appTextTertiary,
                        fontFamily: 'Inter',
                        fontSize: 14),
                    filled: true,
                    fillColor: context.appInputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              state.submitting
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : GestureDetector(
                      onTap: onSubmit,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.appInteractive,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Avatar
// ============================================================================

class _Avatar extends StatelessWidget {
  final String displayName;
  final double size;
  const _Avatar({required this.displayName, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size * 0.44,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
