import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/copy_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/markdown_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_edit_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_report_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mention_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/study_guide_chip.dart';

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
    final palette = ReaderPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.page,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.outline,
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

  /// Scrolls with the replies, above them (the post itself on the post
  /// detail screen). Shown in every state, including loading and empty.
  final Widget? header;

  const FellowshipCommentsBody({
    required this.postId,
    required this.fellowshipId,
    required this.isMentor,
    required this.currentUserId,
    this.scrollController,
    this.header,
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

  /// A state message (loading / empty / failure) under the optional header.
  Widget _stateView(Widget message) {
    final header = widget.header;
    if (header == null) return Center(child: message);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        header,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: message),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
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
                return _stateView(
                  CircularProgressIndicator(color: palette.accentIcon),
                );
              }
              if (state.commentsStatus == FellowshipCommentsStatus.failure ||
                  state.comments.isEmpty) {
                return _stateView(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      state.commentsStatus == FellowshipCommentsStatus.failure
                          ? (state.errorMessage ??
                              context.tr(TranslationKeys
                                  .communityFellowshipCommentsLoadFailed))
                          : context.tr(
                              TranslationKeys.communityFellowshipCommentsEmpty),
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 15,
                        color: palette.muted,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              }
              final header = widget.header;
              final offset = header == null ? 0 : 1;
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: state.comments.length + offset,
                itemBuilder: (context, index) {
                  if (header != null && index == 0) return header;
                  final comment = state.comments[index - offset];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommentTile(
                      comment: comment,
                      postId: widget.postId,
                      fellowshipId: widget.fellowshipId,
                      isMentor: widget.isMentor,
                      currentUserId: widget.currentUserId,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Compose row ────────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.page,
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 12, 8 + bottomInset),
              child: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                buildWhen: (prev, curr) =>
                    prev.commentSubmitting != curr.commentSubmitting,
                builder: (context, state) {
                  return Row(
                    children: [
                      IconButton(
                        tooltip: context
                            .tr(TranslationKeys.communityFellowshipMention),
                        onPressed: () => _openMentionSheet(),
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: Icon(Icons.alternate_email_rounded,
                            size: 24, color: palette.muted),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                palette.isDark ? palette.card : palette.raised,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: palette.hairline),
                          ),
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  maxLength: 500,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  buildCounter: (_,
                                          {required currentLength,
                                          required isFocused,
                                          maxLength}) =>
                                      null,
                                  style: AppFonts.inter(
                                    fontSize: 15,
                                    color: palette.text,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.tr(TranslationKeys
                                        .communityFellowshipCommentHint),
                                    hintStyle: AppFonts.inter(
                                      fontSize: 15,
                                      color: palette.dim,
                                    ),
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                  onChanged: _handleCommentChanged,
                                  onSubmitted: (_) => _submit(),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _SendButton(
                                submitting: state.commentSubmitting,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Round ctaFill send button of the comment composer.
class _SendButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;

  const _SendButton({required this.submitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Tooltip(
      message: context.tr(TranslationKeys.communityFellowshipSend),
      child: SizedBox(
        width: 44,
        height: 44,
        child: ElevatedButton(
          onPressed: submitting ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.ctaFill,
            disabledBackgroundColor: palette.ctaFill.withValues(alpha: 0.6),
            foregroundColor: palette.ctaInk,
            disabledForegroundColor: palette.ctaInk,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: palette.ctaInk,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.arrow_upward_rounded, size: 22),
        ),
      ),
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

  /// The reply as plain text for "Copy text": as typed for members (with
  /// `@mentions`), without stray emphasis markers for the Discipler.
  String get _copyText => (comment.authorIsSystem
          ? stripEmphasisMarkers(comment.content)
          : comment.content)
      .trim();

  @override
  Widget build(BuildContext context) {
    // Long-press anywhere on the reply opens its ⋮ menu.
    return LongPressMenuScope(
      builder: (context, menuKey) => GestureDetector(
        onLongPress: () => openLongPressMenu(menuKey),
        behavior: HitTestBehavior.opaque,
        child: _buildTile(context, menuKey),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    GlobalKey<PopupMenuButtonState<String>> menuKey,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final errorColor =
        palette.isDark ? AppColors.errorLighter : AppColors.errorDark;
    final isSystem = comment.authorIsSystem;
    final canDelete = isMentor || comment.authorUserId == currentUserId;
    final canEdit = isMentor && isSystem;
    final canReport =
        !isSystem && !isMentor && comment.authorUserId != currentUserId;
    final canBlock = !isSystem && comment.authorUserId != currentUserId;
    final copyText = _copyText;
    final canCopy = copyText.isNotEmpty;
    final hasMenu = canCopy || canEdit || canDelete || canReport || canBlock;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isSystem
            ? const DisciplerAvatar()
            : MemberAvatar(
                displayName: comment.authorDisplayName,
                avatarUrl: comment.authorAvatarUrl,
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding:
                EdgeInsetsDirectional.fromSTEB(16, 12, hasMenu ? 4 : 16, 14),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSystem
                    ? palette.gold
                        .withValues(alpha: palette.isDark ? 0.30 : 0.35)
                    : palette.hairline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isSystem
                                  ? l10n.disciplerName
                                  : comment.authorDisplayName,
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                            if (isSystem) const DisciplerAiChip(),
                            PostTimestamp(createdAt: comment.createdAt),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: mentionSpans(
                            isSystem
                                ? stripEmphasisMarkers(comment.content)
                                : comment.content,
                            AppFonts.inter(
                              fontSize: 15,
                              color: palette.text,
                              height: 1.5,
                            ),
                            AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: palette.accentIcon,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (comment.hasGuide) ...[
                        const SizedBox(height: 10),
                        StudyGuideChip(
                          studyGuideId: comment.studyGuideId,
                          title: comment.guideTitle ?? l10n.openStudyGuide,
                          inputType: comment.guideInputType,
                          inputValue: comment.guideInputValue,
                          language: comment.guideLanguage,
                        ),
                      ],
                      if (isSystem) ...[
                        const SizedBox(height: 10),
                        const DisciplerFooterNote(),
                      ],
                      if (comment.isPendingReview) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.gold.withValues(
                                    alpha: palette.isDark ? 0.18 : 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.disciplerDraftBadge,
                                style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: palette.gold,
                                ),
                              ),
                            ),
                            if (isMentor) ...[
                              _ReviewAction(
                                label: l10n.approve,
                                color: palette.isDark
                                    ? AppColors.successLighter
                                    : AppColors.successDark,
                                onTap: () => context
                                    .read<FellowshipFeedBloc>()
                                    .add(FellowshipDisciplerCommentReviewed(
                                      commentId: comment.id,
                                      approve: true,
                                    )),
                              ),
                              _ReviewAction(
                                label: l10n.discard,
                                color: errorColor,
                                onTap: () => context
                                    .read<FellowshipFeedBloc>()
                                    .add(FellowshipDisciplerCommentReviewed(
                                      commentId: comment.id,
                                      approve: false,
                                    )),
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
                if (hasMenu)
                  PopupMenuButton<String>(
                    key: menuKey,
                    tooltip:
                        context.tr(TranslationKeys.communitySharedMoreOptions),
                    icon: Icon(Icons.more_vert, size: 20, color: palette.muted),
                    padding: EdgeInsets.zero,
                    color: palette.card,
                    onSelected: (value) async {
                      if (value == 'copy') {
                        await copyCommunityText(context, copyText);
                        return;
                      }
                      final bloc = context.read<FellowshipFeedBloc>();
                      if (value == 'edit') {
                        final text = await showDisciplerEditDialog(
                          context,
                          initialText: comment.content,
                          maxLength: 2000,
                        );
                        if (text != null) {
                          bloc.add(FellowshipCommentEditRequested(
                            commentId: comment.id,
                            content: text,
                          ));
                        }
                      } else if (value == 'delete') {
                        bloc.add(FellowshipCommentDeleteRequested(
                          commentId: comment.id,
                          postId: postId,
                        ));
                      } else if (value == 'report') {
                        await showModalBottomSheet<void>(
                          useRootNavigator: true,
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
                      if (canCopy)
                        PopupMenuItem<String>(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded,
                                  color: palette.muted, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  context.tr(
                                      TranslationKeys.communityPostCopyText),
                                  style: TextStyle(color: palette.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (canEdit)
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: palette.muted, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.editAction,
                                  style: TextStyle(color: palette.text)),
                            ],
                          ),
                        ),
                      if (canDelete)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: errorColor, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.deleteAction,
                                  style: TextStyle(color: errorColor)),
                            ],
                          ),
                        ),
                      if (canReport)
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined,
                                  color: palette.muted, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.reportTitle,
                                  style: TextStyle(color: palette.text)),
                            ],
                          ),
                        ),
                      if (canBlock)
                        PopupMenuItem<String>(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: errorColor, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.blockUserTitle,
                                  style: TextStyle(color: errorColor)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Text action on a Discipler draft reply (approve / discard), 44px tall.
class _ReviewAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReviewAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
