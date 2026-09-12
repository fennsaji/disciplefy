import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../utils/auth_helpers.dart';
import '../utils/share_helpers.dart';
import '../widgets/block_user_dialog.dart';
import '../widgets/fellowship_comments_sheet.dart';
import '../widgets/fellowship_post_card.dart';
import '../widgets/fellowship_report_sheet.dart';

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
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Post',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
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
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }
            return Center(
              child: Text(
                "This post isn't available. It may have been removed.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: context.appTextSecondary,
                ),
              ),
            );
          }

          final isAdmin = isViewerAdmin(context);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: FellowshipPostCard(
                  post: post,
                  fellowshipId: widget.fellowshipId,
                  isMentor: state.isMentor,
                  currentUserId: state.currentUserId,
                  isAdmin: isAdmin,
                  // No comment button here — the whole thread is already
                  // open below, so there is nothing left for it to open.
                  onShareTap: () =>
                      sharePost(context, post, widget.fellowshipName),
                  onReportTap: () {
                    showModalBottomSheet<void>(
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
              ),
              Divider(color: context.appDivider, height: 1),
              Expanded(
                child: FellowshipCommentsBody(
                  postId: widget.postId,
                  fellowshipId: widget.fellowshipId,
                  isMentor: state.isMentor,
                  currentUserId: state.currentUserId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
