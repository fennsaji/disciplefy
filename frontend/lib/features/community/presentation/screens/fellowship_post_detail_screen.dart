import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/auth_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/share_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_comments_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_report_sheet.dart';

/// A single post, full-width, with its whole comment thread below it.
///
/// This is what a shared post link opens into: dropping the reader into the
/// full feed and quietly flipping an "active comments" flag — with nothing
/// on screen ever reacting to that flag — showed them the fellowship feed
/// and nothing else. Whoever handed them the link wanted them to read this
/// one post and its comments, not go hunting for it.
class FellowshipPostDetailScreen extends StatefulWidget {
  final String fellowshipId;
  final String? fellowshipName;
  final String postId;

  const FellowshipPostDetailScreen({
    required this.fellowshipId,
    required this.postId,
    this.fellowshipName,
    super.key,
  });

  @override
  State<FellowshipPostDetailScreen> createState() =>
      _FellowshipPostDetailScreenState();
}

class _FellowshipPostDetailScreenState
    extends State<FellowshipPostDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Sets the comment thread's target post before the first frame, so the
    // compose row below is already wired to the right post.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<FellowshipFeedBloc>()
          .add(FellowshipCommentsOpenRequested(postId: widget.postId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: context.tr(TranslationKeys.communityFellowshipPostTitle),
        background: palette.page,
      ),
      body: BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
        buildWhen: (prev, curr) =>
            prev.posts != curr.posts || prev.status != curr.status,
        builder: (context, state) {
          final post =
              state.posts.where((p) => p.id == widget.postId).firstOrNull;

          if (post == null) {
            if (state.status == FellowshipFeedStatus.loading) {
              return Center(
                child: CircularProgressIndicator(color: palette.accentIcon),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context
                      .tr(TranslationKeys.communityFellowshipPostUnavailable),
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 15,
                    color: palette.muted,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }

          // The post scrolls with its replies, so a long post never leaves
          // the thread squeezed into a sliver at the bottom of the screen.
          return FellowshipCommentsBody(
            postId: widget.postId,
            fellowshipId: widget.fellowshipId,
            isMentor: state.isMentor,
            currentUserId: state.currentUserId,
            header: _PostHeader(
              post: post,
              fellowshipId: widget.fellowshipId,
              fellowshipName: widget.fellowshipName,
              state: state,
            ),
          );
        },
      ),
    );
  }
}

/// The post card followed by the "N replies" label.
class _PostHeader extends StatelessWidget {
  final FellowshipPostEntity post;
  final String fellowshipId;
  final String? fellowshipName;
  final FellowshipFeedState state;

  const _PostHeader({
    required this.post,
    required this.fellowshipId,
    required this.fellowshipName,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isAdmin = isViewerAdmin(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FellowshipPostCard(
          post: post,
          fellowshipId: fellowshipId,
          isMentor: state.isMentor,
          currentUserId: state.currentUserId,
          isAdmin: isAdmin,
          // No comment button here — the whole thread is already
          // open below, so there is nothing left for it to open.
          onShareTap: () => sharePost(context, post, fellowshipName),
          onReportTap: () {
            showModalBottomSheet<void>(
              useRootNavigator: true,
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: context.read<FellowshipFeedBloc>(),
                child: FellowshipReportSheet(
                  fellowshipId: fellowshipId,
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
                fellowshipId: fellowshipId,
                contentType: 'post',
                contentId: post.id,
              ));
            }
          },
        ),
        BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
          buildWhen: (prev, curr) =>
              prev.comments.length != curr.comments.length ||
              prev.commentsStatus != curr.commentsStatus,
          builder: (context, commentsState) {
            final count = commentsState.comments.length;
            if (commentsState.commentsStatus !=
                    FellowshipCommentsStatus.success ||
                count == 0) {
              return const SizedBox(height: 16);
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 16),
              child: Text(
                postRepliesLabel(context, count),
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
