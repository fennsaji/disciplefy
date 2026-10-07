import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_post_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/auth_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/feed_sort.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/share_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_comments_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_report_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mention_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Real implementation of the Fellowship Feed tab.
///
/// Reads the [FellowshipFeedBloc] provided by [FellowshipHomeScreen] —
/// it does NOT create a new BlocProvider.
class FellowshipFeedTabScreen extends StatelessWidget {
  /// The ID of the fellowship whose feed is displayed.
  final String fellowshipId;

  /// Display name of the fellowship, used for the share text.
  final String? fellowshipName;

  const FellowshipFeedTabScreen({
    required this.fellowshipId,
    this.fellowshipName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _FellowshipFeedView(
      fellowshipId: fellowshipId,
      fellowshipName: fellowshipName,
    );
  }
}

// ---------------------------------------------------------------------------
// Main feed view — owns the scroll controller for infinite scrolling.
// ---------------------------------------------------------------------------

class _FellowshipFeedView extends StatefulWidget {
  final String fellowshipId;
  final String? fellowshipName;

  const _FellowshipFeedView({required this.fellowshipId, this.fellowshipName});

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
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<FellowshipFeedBloc>(),
        child: FellowshipCreatePostSheet(fellowshipId: widget.fellowshipId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return BlocListener<FellowshipFeedBloc, FellowshipFeedState>(
      listenWhen: (prev, curr) => prev.blockStatus != curr.blockStatus,
      listener: (context, state) {
        if (state.blockStatus == FellowshipBlockStatus.success) {
          showAppSnackBar(context, l10n.blockUserSuccess,
              tone: AppSnackTone.success);
        } else if (state.blockStatus == FellowshipBlockStatus.failure) {
          showAppSnackBar(context, state.errorMessage ?? l10n.feedLoadError,
              tone: AppSnackTone.error);
        }
      },
      child: Scaffold(
        backgroundColor: palette.page,
        floatingActionButton:
            BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
          buildWhen: (prev, curr) =>
              prev.canShowPostButton != curr.canShowPostButton,
          builder: (context, state) {
            if (!state.canShowPostButton) return const SizedBox.shrink();
            return CommunityCtaPill(
              large: true,
              icon: Icons.add,
              label: l10n.feedNewPost,
              onPressed: _openCreatePostSheet,
            );
          },
        ),
        body: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
          builder: (context, state) {
            // ── Loading (initial or hard refresh with no posts yet) ──────────
            if ((state.status == FellowshipFeedStatus.initial ||
                    state.status == FellowshipFeedStatus.loading) &&
                state.posts.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: palette.accentIcon),
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
                        color: palette.dim,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? l10n.feedLoadError,
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                          fontSize: 15,
                          color: palette.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CommunityCtaPill(
                        icon: Icons.refresh_rounded,
                        label: l10n.feedRetry,
                        onPressed: () {
                          context.read<FellowshipFeedBloc>().add(
                                FellowshipFeedLoadRequested(
                                  fellowshipId: widget.fellowshipId,
                                ),
                              );
                        },
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
                color: palette.accentIcon,
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 56,
                      color: palette.dim,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.canPost ? l10n.feedEmpty : l10n.feedEmptyReadOnly,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 16,
                        color: palette.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── List state ────────────────────────────────────────────────
            final sortedPosts = sortFeed(state.posts);
            final isAdmin = isViewerAdmin(context);
            return RefreshIndicator(
              color: palette.accentIcon,
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 100, // space above FAB
                ),
                itemCount: sortedPosts.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == sortedPosts.length) {
                    // Pagination loading indicator at the bottom.
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: palette.accentIcon,
                          strokeWidth: 2.5,
                        ),
                      ),
                    );
                  }
                  final post = sortedPosts[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: FellowshipPostCard(
                      post: post,
                      fellowshipId: widget.fellowshipId,
                      isMentor: state.isMentor,
                      currentUserId: state.currentUserId,
                      isAdmin: isAdmin,
                      maxContentLines: FellowshipPostCard.feedMaxContentLines,
                      onPostTap: () {
                        final bloc = context.read<FellowshipFeedBloc>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: bloc,
                              child: FellowshipPostDetailScreen(
                                fellowshipId: widget.fellowshipId,
                                fellowshipName: widget.fellowshipName,
                                postId: post.id,
                              ),
                            ),
                          ),
                        );
                      },
                      onShareTap: () =>
                          sharePost(context, post, widget.fellowshipName),
                      onCommentTap: () {
                        context.read<FellowshipFeedBloc>().add(
                              FellowshipCommentsOpenRequested(postId: post.id),
                            );
                        showModalBottomSheet<void>(
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BlocProvider.value(
                            value: context.read<FellowshipFeedBloc>(),
                            child: FellowshipCommentsSheet(
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
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BlocProvider.value(
                            value: context.read<FellowshipFeedBloc>(),
                            child: FellowshipReportSheet(
                              fellowshipId: widget.fellowshipId,
                              contentType: 'post',
                              contentId: post.id,
                            ),
                          ),
                        );
                      },
                      onBlockTap: () async {
                        final bloc = context.read<FellowshipFeedBloc>();
                        if (await showBlockUserConfirmation(context)) {
                          bloc.add(FellowshipBlockUserRequested(
                            blockedUserId: post.authorUserId,
                            fellowshipId: widget.fellowshipId,
                            contentType: 'post',
                            contentId: post.id,
                          ));
                        }
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FellowshipCreatePostSheet (public — shared with home screen)
// ---------------------------------------------------------------------------

class FellowshipCreatePostSheet extends StatefulWidget {
  final String fellowshipId;
  final String initialType;

  const FellowshipCreatePostSheet({
    required this.fellowshipId,
    this.initialType = 'general',
    super.key,
  });

  @override
  State<FellowshipCreatePostSheet> createState() =>
      _FellowshipCreatePostSheetState();
}

class _FellowshipCreatePostSheetState extends State<FellowshipCreatePostSheet> {
  final TextEditingController _contentController = TextEditingController();
  late String _selectedType = widget.initialType;

  /// Mentors can leave one question to the group. Defaults to letting
  /// Discipler answer, so ignoring the switch changes nothing.
  bool _letDisciplerAnswer = true;

  /// Who the inserted @handles refer to, resolved at insertion time.
  final MentionTracker _mentions = MentionTracker();

  /// Fellowship members, fetched the first time the picker is opened.
  List<FellowshipMemberEntity> _members = const [];

  /// Returns contextual placeholder text based on the selected post type.
  String _hintForType(BuildContext context, String type) {
    switch (type) {
      case 'prayer':
        return context.tr(TranslationKeys.communityFellowshipPostHintPrayer);
      case 'praise':
        return context.tr(TranslationKeys.communityFellowshipPostHintPraise);
      case 'question':
        return context.tr(TranslationKeys.communityFellowshipPostHintQuestion);
      default:
        return context.tr(TranslationKeys.communityFellowshipPostHintGeneral);
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
            disciplerReplyOptOut: !_letDisciplerAnswer,
            mentionedUserIds: _mentions.idsIn(content),
          ),
        );
  }

  /// Watches for `'@'` typed at the start of a word and opens the mention
  /// picker automatically.
  void _handleContentChanged(String text) {
    final cursor = _contentController.selection.baseOffset;
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
        _contentController.text,
        cursorOverride ?? _contentController.selection.baseOffset,
      ),
    );
    if (candidate == null || !mounted) return;
    _mentions.remember(candidate.handle, candidate.userId);
    final selectionOffset = _contentController.selection.baseOffset;
    final cursor = cursorOverride ??
        (selectionOffset >= 0
            ? selectionOffset
            : _contentController.text.length);
    final result =
        insertMention(_contentController.text, cursor, candidate.handle);
    _contentController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
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
        description:
            context.tr(TranslationKeys.communityFellowshipTypeDescGeneral),
        icon: Icons.chat_rounded,
        accent: AppColors.brandHighlightDark,
      ),
      (
        value: 'prayer',
        label: l10n.postTypePrayer,
        description:
            context.tr(TranslationKeys.communityFellowshipTypeDescPrayer),
        icon: Icons.volunteer_activism_rounded,
        accent: AppColors.info,
      ),
      (
        value: 'praise',
        label: l10n.postTypePraise,
        description:
            context.tr(TranslationKeys.communityFellowshipTypeDescPraise),
        icon: Icons.emoji_events_rounded,
        accent: AppColors.warning,
      ),
      (
        value: 'question',
        label: l10n.postTypeQuestion,
        description:
            context.tr(TranslationKeys.communityFellowshipTypeDescQuestion),
        icon: Icons.help_outline_rounded,
        accent: AppColors.success,
      ),
    ];

    Widget typeCard(
        ({
          String value,
          String label,
          String description,
          IconData icon,
          Color accent,
        }) t) {
      final isSelected = _selectedType == t.value;
      // The raw accent is tuned as a fill, not as text: on the dark card
      // some accents fall well under the 4.5:1 minimum. Lift it
      // against the surface it is actually drawn on; fills and borders keep
      // the original.
      final accent = t.accent;
      final accentText = ensureContrast(accent, palette.raised);
      return Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: isSelected ? accent.withAlpha(26) : palette.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedType = t.value),
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? accent.withAlpha(51) : palette.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        t.icon,
                        size: 18,
                        // Same corrected colour as the label: the icon sits
                        // on `accent.withAlpha(51)` over the card, so the raw
                        // accent nearly matches its own background.
                        color: isSelected ? accentText : palette.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.label,
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? accentText : palette.text,
                            ),
                          ),
                          Text(
                            t.description,
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: palette.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24 + bottomInset),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ──────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ───────────────────────────────────────────────
                Text(
                  l10n.feedCreateTitle,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Post type selector ──────────────────────────────────
                CommunitySheetLabel(l10n.feedCreateTypeLabel),
                const SizedBox(height: 10),
                // 2×2 grid of type cards. IntrinsicHeight keeps both cards
                // of a row the same height when one label wraps.
                for (int row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 8),
                          Expanded(child: typeCard(postTypes[row * 2 + col])),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ── Content field ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: CommunitySheetLabel(l10n.feedCreateContentLabel),
                    ),
                    IconButton(
                      tooltip: context
                          .tr(TranslationKeys.communityFellowshipMention),
                      onPressed: () => _openMentionSheet(),
                      icon: Icon(Icons.alternate_email_rounded,
                          size: 20, color: palette.muted),
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _contentController,
                  maxLines: 5,
                  maxLength: 256,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  onChanged: _handleContentChanged,
                  style: AppFonts.inter(fontSize: 15, color: palette.text),
                  decoration: communityInputDecoration(
                    context,
                    hintText: _hintForType(context, _selectedType),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                // ── Discipler opt-out (mentors, question posts) ─────────
                BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                  buildWhen: (prev, curr) =>
                      prev.isMentor != curr.isMentor ||
                      prev.disciplerAllowed != curr.disciplerAllowed,
                  builder: (context, state) {
                    if (!state.isMentor ||
                        !state.disciplerAllowed ||
                        _selectedType != 'question') {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SwitchListTile.adaptive(
                        value: _letDisciplerAnswer,
                        onChanged: (v) =>
                            setState(() => _letDisciplerAnswer = v),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context
                              .tr(TranslationKeys.fellowshipLetDisciplerAnswer),
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        subtitle: Text(
                          context.tr(
                              TranslationKeys.fellowshipLetDisciplerAnswerHint),
                          style: AppFonts.inter(
                            fontSize: 13,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Submit button ───────────────────────────────────────
                BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
                  buildWhen: (prev, curr) => prev.submitting != curr.submitting,
                  builder: (context, state) {
                    final submitting = state.submitting;
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.ctaFill,
                          foregroundColor: palette.ctaInk,
                          disabledBackgroundColor:
                              palette.ctaFill.withValues(alpha: 0.5),
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: submitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: palette.ctaInk,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                l10n.feedCreatePost,
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ctaInk,
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
    );
  }
}

/// Small muted field label inside community sheets ("Post type", "Message").
class CommunitySheetLabel extends StatelessWidget {
  final String text;

  const CommunitySheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ReaderPalette.of(context).muted,
      ),
    );
  }
}
