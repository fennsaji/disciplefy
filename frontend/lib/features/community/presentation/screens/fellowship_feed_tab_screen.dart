import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../widgets/fellowship_post_card.dart';

/// Real implementation of the Fellowship Feed tab.
///
/// Reads the [FellowshipFeedBloc] provided by [FellowshipHomeScreen] —
/// it does NOT create a new BlocProvider.
class FellowshipFeedTabScreen extends StatelessWidget {
  /// The ID of the fellowship whose feed is displayed.
  final String fellowshipId;

  const FellowshipFeedTabScreen({
    required this.fellowshipId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _FellowshipFeedView(fellowshipId: fellowshipId);
  }
}

// ---------------------------------------------------------------------------
// Main feed view — owns the scroll controller for infinite scrolling.
// ---------------------------------------------------------------------------

class _FellowshipFeedView extends StatefulWidget {
  final String fellowshipId;

  const _FellowshipFeedView({required this.fellowshipId});

  @override
  State<_FellowshipFeedView> createState() => _FellowshipFeedViewState();
}

class _FellowshipFeedViewState extends State<_FellowshipFeedView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentExtent = _scrollController.offset;
    // Trigger load-more when within 200px of the bottom.
    if (maxExtent - currentExtent <= 200) {
      final state = context.read<FellowshipFeedBloc>().state;
      if (state.hasMore && state.status != FellowshipFeedStatus.loading) {
        context.read<FellowshipFeedBloc>().add(
              FellowshipFeedLoadMoreRequested(
                fellowshipId: widget.fellowshipId,
              ),
            );
      }
    }
  }

  Future<void> _onRefresh() async {
    context.read<FellowshipFeedBloc>().add(
          FellowshipFeedLoadRequested(fellowshipId: widget.fellowshipId),
        );
    // Wait briefly so the refresh indicator dismisses naturally.
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  void _openCreatePostSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<FellowshipFeedBloc>(),
        child: _CreatePostSheet(fellowshipId: widget.fellowshipId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePostSheet,
        backgroundColor: context.appInteractive,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          l10n.feedNewPost,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      body: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
        builder: (context, state) {
          // ── Loading (initial or hard refresh with no posts yet) ──────────
          if ((state.status == FellowshipFeedStatus.initial ||
                  state.status == FellowshipFeedStatus.loading) &&
              state.posts.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          // ── Error state ────────────────────────────────────────────────
          if (state.status == FellowshipFeedStatus.failure &&
              state.posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: context.appTextTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? l10n.feedLoadError,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appInteractive,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        context.read<FellowshipFeedBloc>().add(
                              FellowshipFeedLoadRequested(
                                fellowshipId: widget.fellowshipId,
                              ),
                            );
                      },
                      child: Text(
                        l10n.feedRetry,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Empty state (success + no posts) ──────────────────────────
          if (state.status == FellowshipFeedStatus.success &&
              state.posts.isEmpty) {
            return RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: context.appTextTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.feedEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: context.appTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ── List state ────────────────────────────────────────────────
          return RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: _onRefresh,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                top: 12,
                bottom: 100, // space above FAB
              ),
              itemCount: state.posts.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.posts.length) {
                  // Pagination loading indicator at the bottom.
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }
                final post = state.posts[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: FellowshipPostCard(
                    post: post,
                    fellowshipId: widget.fellowshipId,
                    isMentor: state.isMentor,
                    currentUserId: state.currentUserId,
                    onCommentTap: () {
                      context.read<FellowshipFeedBloc>().add(
                            FellowshipCommentsOpenRequested(postId: post.id),
                          );
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: context.read<FellowshipFeedBloc>(),
                          child: _CommentsSheet(
                            postId: post.id,
                            fellowshipId: widget.fellowshipId,
                            isMentor: state.isMentor,
                            currentUserId: state.currentUserId,
                          ),
                        ),
                      );
                    },
                    onReportTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: context.read<FellowshipFeedBloc>(),
                          child: _ReportSheet(
                            fellowshipId: widget.fellowshipId,
                            contentType: 'post',
                            contentId: post.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CommentsSheet
// ---------------------------------------------------------------------------

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  const _CommentsSheet({
    required this.postId,
    required this.fellowshipId,
    required this.isMentor,
    required this.currentUserId,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<FellowshipFeedBloc>().add(
          FellowshipCommentCreateRequested(content: text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── Comment list ───────────────────────────────────────
              Expanded(
                child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                  buildWhen: (prev, curr) =>
                      prev.comments != curr.comments ||
                      prev.commentsStatus != curr.commentsStatus,
                  builder: (context, state) {
                    if (state.commentsStatus ==
                        FellowshipCommentsStatus.loading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }
                    if (state.commentsStatus ==
                            FellowshipCommentsStatus.failure ||
                        state.comments.isEmpty) {
                      return Center(
                        child: Text(
                          state.commentsStatus ==
                                  FellowshipCommentsStatus.failure
                              ? (state.errorMessage ?? 'Failed to load')
                              : 'No comments yet. Be first!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: context.appTextSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: state.comments.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: context.appDivider, height: 1),
                      itemBuilder: (context, index) {
                        final comment = state.comments[index];
                        final canDelete = widget.isMentor ||
                            comment.authorUserId == widget.currentUserId;
                        final canReport = !widget.isMentor &&
                            comment.authorUserId != widget.currentUserId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(26),
                                child: Text(
                                  comment.authorDisplayName.isNotEmpty
                                      ? comment.authorDisplayName[0]
                                          .toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment.authorDisplayName,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.appTextPrimary,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (canDelete)
                                          GestureDetector(
                                            onTap: () => context
                                                .read<FellowshipFeedBloc>()
                                                .add(
                                                  FellowshipCommentDeleteRequested(
                                                    commentId: comment.id,
                                                    postId: widget.postId,
                                                  ),
                                                ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: context.appTextTertiary,
                                            ),
                                          ),
                                        if (canReport)
                                          GestureDetector(
                                            onTap: () {
                                              showModalBottomSheet<void>(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor:
                                                    Colors.transparent,
                                                builder: (_) =>
                                                    BlocProvider.value(
                                                  value: context.read<
                                                      FellowshipFeedBloc>(),
                                                  child: _ReportSheet(
                                                    fellowshipId:
                                                        widget.fellowshipId,
                                                    contentType: 'comment',
                                                    contentId: comment.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Icon(
                                              Icons.flag_outlined,
                                              size: 16,
                                              color: context.appTextTertiary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      comment.content,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: context.appTextPrimary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Compose row ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
                child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                  buildWhen: (prev, curr) =>
                      prev.commentSubmitting != curr.commentSubmitting,
                  builder: (context, state) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: 500,
                            buildCounter: (_,
                                    {required currentLength,
                                    required isFocused,
                                    maxLength}) =>
                                null,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: context.appTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: context.appTextTertiary,
                              ),
                              filled: true,
                              fillColor: context.appScaffold,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: context.appBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide:
                                    BorderSide(color: context.appBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: state.commentSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.appInteractive,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: state.commentSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _CreatePostSheet
// ---------------------------------------------------------------------------

class _CreatePostSheet extends StatefulWidget {
  final String fellowshipId;

  const _CreatePostSheet({required this.fellowshipId});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedType = 'general';

  /// Returns contextual placeholder text based on the selected post type.
  String _hintForType(String type) {
    switch (type) {
      case 'prayer':
        return 'Share a prayer request with your fellowship…';
      case 'praise':
        return 'Celebrate what God has done! Share your praise…';
      case 'question':
        return 'Ask a question about faith or Scripture…';
      default:
        return "What's on your heart?";
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;
    context.read<FellowshipFeedBloc>().add(
          FellowshipPostCreateRequested(
            fellowshipId: widget.fellowshipId,
            content: content,
            postType: _selectedType,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final List<
        ({
          String value,
          String label,
          String description,
          IconData icon,
          Color accent,
        })> postTypes = [
      (
        value: 'general',
        label: l10n.postTypeGeneral,
        description: 'Share anything',
        icon: Icons.chat_rounded,
        accent: AppColors.brandPrimary,
      ),
      (
        value: 'prayer',
        label: l10n.postTypePrayer,
        description: 'Prayer request',
        icon: Icons.volunteer_activism_rounded,
        accent: AppColors.info,
      ),
      (
        value: 'praise',
        label: l10n.postTypePraise,
        description: 'Praise God',
        icon: Icons.emoji_events_rounded,
        accent: AppColors.warning,
      ),
      (
        value: 'question',
        label: l10n.postTypeQuestion,
        description: 'Ask anything',
        icon: Icons.help_outline_rounded,
        accent: AppColors.success,
      ),
    ];

    return BlocListener<FellowshipFeedBloc, FellowshipFeedState>(
      listenWhen: (prev, curr) =>
          // Close sheet when submitting transitions to false (success).
          (prev.submitting && !curr.submitting) ||
          // Also close if a new post appeared in the list (create succeeded).
          (prev.posts.length < curr.posts.length),
      listener: (context, state) {
        if (mounted) Navigator.of(context).maybePop();
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ─────────────────────────────────────────────────
            Text(
              l10n.feedCreateTitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── Post type selector ────────────────────────────────────
            Text(
              l10n.feedCreateTypeLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // 2×2 grid of type cards
            for (int row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (int col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (context) {
                        final t = postTypes[row * 2 + col];
                        final isSelected = _selectedType == t.value;
                        final accent = t.accent;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = t.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withAlpha(26)
                                  : context.appSurfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? accent : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withAlpha(51)
                                        : context.appSurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    t.icon,
                                    size: 18,
                                    color: isSelected
                                        ? accent
                                        : context.appTextTertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.label,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? accent
                                              : context.appTextPrimary,
                                        ),
                                      ),
                                      Text(
                                        t.description,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          color: context.appTextTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),

            // ── Content field ─────────────────────────────────────────
            Text(
              l10n.feedCreateContentLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 5,
              maxLength: 256,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: _hintForType(_selectedType),
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  color: context.appTextTertiary,
                ),
                filled: true,
                fillColor: context.appScaffold,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────
            BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
              buildWhen: (prev, curr) => prev.submitting != curr.submitting,
              builder: (context, state) {
                final submitting = state.submitting;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appInteractive,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          context.appInteractive.withAlpha(128),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            l10n.feedCreatePost,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReportSheet
// ---------------------------------------------------------------------------

class _ReportSheet extends StatefulWidget {
  final String fellowshipId;
  final String contentType; // 'post' or 'comment'
  final String contentId;

  const _ReportSheet({
    required this.fellowshipId,
    required this.contentType,
    required this.contentId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<FellowshipFeedBloc>().add(
          FellowshipReportRequested(
            fellowshipId: widget.fellowshipId,
            contentType: widget.contentType,
            contentId: widget.contentId,
            reason: _reasonController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<FellowshipFeedBloc, FellowshipFeedState>(
      listenWhen: (prev, curr) => prev.reportStatus != curr.reportStatus,
      listener: (context, state) {
        if (state.reportStatus == FellowshipReportStatus.success) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.reportSuccess),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.reportTitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    maxLength: 500,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.reportReasonLabel,
                      hintText: l10n.reportReasonHint,
                      filled: true,
                      fillColor: context.appInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 5) {
                        return 'Please provide at least 5 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                    buildWhen: (prev, curr) =>
                        prev.reportStatus != curr.reportStatus,
                    builder: (context, state) {
                      final loading =
                          state.reportStatus == FellowshipReportStatus.loading;
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.appInteractive,
                            foregroundColor: AppColors.onGradient,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onGradient,
                                  ),
                                )
                              : Text(
                                  l10n.reportSubmit,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
