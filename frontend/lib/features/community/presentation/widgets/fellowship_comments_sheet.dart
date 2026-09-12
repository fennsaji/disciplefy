import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_comment_entity.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../utils/auth_helpers.dart';
import '../utils/feed_sort.dart';
import '../utils/markdown_text.dart';
import '../utils/mention_text.dart';
import '../utils/share_helpers.dart';
import '../widgets/block_user_dialog.dart';
import '../widgets/discipler_badges.dart';
import '../widgets/fellowship_post_card.dart';
import '../widgets/mention_sheet.dart';
import '../widgets/study_guide_chip.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'fellowship_report_sheet.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'member_avatar.dart';

/// Comment thread for one post, opened as a modal bottom sheet.
///
/// Shared by the feed and the fellowship home preview so a post's comments
/// look and behave the same wherever the card is shown.
///
/// This is a thin wrapper around [FellowshipCommentsBody] that adds the
/// bottom-sheet chrome (drag handle, rounded top, draggable sizing).
/// [FellowshipPostDetailScreen] uses the body directly, full-page, without
/// any of that chrome.
class FellowshipCommentsSheet extends StatelessWidget {
  final String postId;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  const FellowshipCommentsSheet({
    required this.postId,
    required this.fellowshipId,
    required this.isMentor,
    required this.currentUserId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: FellowshipCommentsBody(
                  postId: postId,
                  fellowshipId: fellowshipId,
                  isMentor: isMentor,
                  currentUserId: currentUserId,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The comment list and composer, without any bottom-sheet chrome — the part
/// [FellowshipCommentsSheet] and [FellowshipPostDetailScreen] both need.
class FellowshipCommentsBody extends StatefulWidget {
  final String postId;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  /// Only meaningful inside a [DraggableScrollableSheet]; `null` when used
  /// full-page, where the list scrolls on its own.
  final ScrollController? scrollController;

  const FellowshipCommentsBody({
    required this.postId,
    required this.fellowshipId,
    required this.isMentor,
    required this.currentUserId,
    this.scrollController,
    super.key,
  });

  @override
  State<FellowshipCommentsBody> createState() => FellowshipCommentsBodyState();
}

class FellowshipCommentsBodyState extends State<FellowshipCommentsBody> {
  final TextEditingController _controller = TextEditingController();

  final MentionTracker _mentions = MentionTracker();

  List<FellowshipMemberEntity> _members = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final mentioned = _mentions.idsIn(text);
    _controller.clear();
    _mentions.clear();
    context.read<FellowshipFeedBloc>().add(
          FellowshipCommentCreateRequested(
            content: text,
            mentionedUserIds: mentioned,
          ),
        );
  }

  /// Watches for `'@'` typed at the start of a word and opens the mention
  /// picker automatically.
  void _handleCommentChanged(String text) {
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    if (shouldOpenMentionSheet(text, cursor)) {
      _openMentionSheet(cursorOverride: cursor);
    }
  }

  /// Opens the `@mention` picker and, on selection, inserts the handle at the
  /// current cursor position (replacing a trailing partial `@word`).
  Future<void> _openMentionSheet({int? cursorOverride}) async {
    final feedState = context.read<FellowshipFeedBloc>().state;
    if (_members.isEmpty) {
      final result = await sl<CommunityRepository>()
          .getFellowshipMembers(widget.fellowshipId);
      result.fold((_) => null, (members) => _members = members);
      if (!mounted) return;
    }
    final candidate = await showMentionSheet(
      context,
      disciplerAllowed: feedState.disciplerAllowed,
      mentors: feedState.mentors,
      members: _members,
      currentUserId: feedState.currentUserId,
      initialQuery: mentionQueryAt(
        _controller.text,
        cursorOverride ?? _controller.selection.baseOffset,
      ),
    );
    if (candidate == null || !mounted) return;
    _mentions.remember(candidate.handle, candidate.userId);
    final selectionOffset = _controller.selection.baseOffset;
    final cursor = cursorOverride ??
        (selectionOffset >= 0 ? selectionOffset : _controller.text.length);
    final result = insertMention(_controller.text, cursor, candidate.handle);
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      children: [
        // ── Comment list ───────────────────────────────────────
        Expanded(
          child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
            buildWhen: (prev, curr) =>
                prev.comments != curr.comments ||
                prev.commentsStatus != curr.commentsStatus,
            builder: (context, state) {
              if (state.commentsStatus == FellowshipCommentsStatus.loading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
              if (state.commentsStatus == FellowshipCommentsStatus.failure ||
                  state.comments.isEmpty) {
                return Center(
                  child: Text(
                    state.commentsStatus == FellowshipCommentsStatus.failure
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
                controller: widget.scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: state.comments.length,
                separatorBuilder: (_, __) =>
                    Divider(color: context.appDivider, height: 1),
                itemBuilder: (context, index) {
                  final comment = state.comments[index];
                  return _CommentTile(
                    comment: comment,
                    postId: widget.postId,
                    fellowshipId: widget.fellowshipId,
                    isMentor: widget.isMentor,
                    currentUserId: widget.currentUserId,
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
                  IconButton(
                    onPressed: () => _openMentionSheet(),
                    icon: Icon(Icons.alternate_email_rounded,
                        size: 20, color: context.appTextSecondary),
                  ),
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
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: _handleCommentChanged,
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
    );
  }
}

class _CommentTile extends StatelessWidget {
  final FellowshipCommentEntity comment;
  final String postId;
  final String fellowshipId;
  final bool isMentor;
  final String? currentUserId;

  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.fellowshipId,
    required this.isMentor,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSystem = comment.authorIsSystem;
    final canDelete = isMentor || comment.authorUserId == currentUserId;
    final canReport =
        !isSystem && !isMentor && comment.authorUserId != currentUserId;
    final canBlock = !isSystem && comment.authorUserId != currentUserId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: isSystem
          ? BoxDecoration(
              color: context.appPrimary.withAlpha(
                  Theme.of(context).brightness == Brightness.dark ? 40 : 18),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isSystem
                  ? const DisciplerAvatar(radius: 16)
                  : MemberAvatar(
                      radius: 16,
                      displayName: comment.authorDisplayName,
                      accentColor: Theme.of(context).colorScheme.primary,
                      avatarUrl: comment.authorAvatarUrl,
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
                                : comment.authorDisplayName,
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
                        if (isSystem) ...[
                          const SizedBox(width: 6),
                          const DisciplerAiChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: mentionSpans(
                          isSystem
                              ? stripEmphasisMarkers(comment.content)
                              : comment.content,
                          TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: context.appTextPrimary,
                            height: 1.45,
                          ),
                          TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.appPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    if (comment.hasGuide) ...[
                      const SizedBox(height: 8),
                      StudyGuideChip(
                        studyGuideId: comment.studyGuideId,
                        title: comment.guideTitle ?? l10n.openStudyGuide,
                        inputType: comment.guideInputType,
                        inputValue: comment.guideInputValue,
                        language: comment.guideLanguage,
                      ),
                    ],
                    if (isSystem) ...[
                      const SizedBox(height: 8),
                      const DisciplerFooterNote(),
                    ],
                    if (comment.isPendingReview) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.disciplerDraftBadge,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warningDark,
                              ),
                            ),
                          ),
                          if (isMentor) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context
                                  .read<FellowshipFeedBloc>()
                                  .add(FellowshipDisciplerCommentReviewed(
                                    commentId: comment.id,
                                    approve: true,
                                  )),
                              child: Text(
                                l10n.approve,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.appSuccess,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => context
                                  .read<FellowshipFeedBloc>()
                                  .add(FellowshipDisciplerCommentReviewed(
                                    commentId: comment.id,
                                    approve: false,
                                  )),
                              child: Text(
                                l10n.discard,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.appError,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // One labelled menu rather than a row of bare glyphs:
              // an X on someone's reply reads as "dismiss" when it
              // actually deletes, and the icons gave no wording for
              // what each one does.
              if (canDelete || canReport || canBlock)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      size: 18, color: context.appTextTertiary),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  onSelected: (value) async {
                    final bloc = context.read<FellowshipFeedBloc>();
                    if (value == 'delete') {
                      bloc.add(FellowshipCommentDeleteRequested(
                        commentId: comment.id,
                        postId: postId,
                      ));
                    } else if (value == 'report') {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: FellowshipReportSheet(
                            fellowshipId: fellowshipId,
                            contentType: 'comment',
                            contentId: comment.id,
                          ),
                        ),
                      );
                    } else if (value == 'block') {
                      if (await showBlockUserConfirmation(context)) {
                        bloc.add(FellowshipBlockUserRequested(
                          blockedUserId: comment.authorUserId,
                          fellowshipId: fellowshipId,
                          contentType: 'comment',
                          contentId: comment.id,
                        ));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (canDelete)
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
                      ),
                    if (canReport)
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined,
                                color: context.appTextSecondary, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.reportTitle,
                                style:
                                    TextStyle(color: context.appTextPrimary)),
                          ],
                        ),
                      ),
                    if (canBlock)
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block,
                                color: context.appError, size: 20),
                            const SizedBox(width: 8),
                            Text(l10n.blockUserTitle,
                                style: TextStyle(color: context.appError)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
