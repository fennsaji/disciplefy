import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_event.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_state.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../bloc/fellowship_members/fellowship_members_bloc.dart';
import '../bloc/fellowship_members/fellowship_members_event.dart';
import '../bloc/fellowship_members/fellowship_members_state.dart';
import '../bloc/fellowship_study/fellowship_study_bloc.dart';
import '../bloc/fellowship_study/fellowship_study_event.dart';
import '../bloc/fellowship_study/fellowship_study_state.dart';
import 'fellowship_feed_tab_screen.dart';
import 'fellowship_lessons_tab_screen.dart';
import 'fellowship_members_tab_screen.dart';
import 'fellowship_meetings_tab_screen.dart';
import 'schedule_meeting_sheet.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_event.dart';
import '../bloc/fellowship_meetings/fellowship_meetings_state.dart';
import '../widgets/fellowship_post_card.dart';

// ============================================================================
// Root widget — provides BLoCs, delegates to _FellowshipHomeContent
// ============================================================================

/// Single-page fellowship home screen.
///
/// Replaced the three-tab layout with a scrollable design:
///   • Gradient hero header  (mentor, members, study chip + progress)
///   • Recent Activity       (3–5 post preview + "View All")
///
/// Sub-screens (full feed, lessons, members) are pushed via [Navigator.push]
/// using [BlocProvider.value] so they share the BLoCs provided here.
class FellowshipHomeScreen extends StatefulWidget {
  final String fellowshipId;
  final String? fellowshipName;
  final FellowshipEntity? fellowship;

  const FellowshipHomeScreen({
    required this.fellowshipId,
    this.fellowshipName,
    this.fellowship,
    super.key,
  });

  @override
  State<FellowshipHomeScreen> createState() => _FellowshipHomeScreenState();
}

class _FellowshipHomeScreenState extends State<FellowshipHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final fellowship = widget.fellowship;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMentor = fellowship?.userRole == 'mentor';
    return MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipFeedBloc>(
          create: (_) => sl<FellowshipFeedBloc>()
            ..add(FellowshipFeedInitialized(
              isMentor: isMentor,
              currentUserId: currentUserId,
            ))
            ..add(FellowshipFeedLoadRequested(
              fellowshipId: widget.fellowshipId,
            )),
        ),
        BlocProvider<FellowshipMembersBloc>(
          create: (_) => sl<FellowshipMembersBloc>()
            ..add(FellowshipMembersInitialized(
              isMentor: isMentor,
              fellowshipId: widget.fellowshipId,
              currentUserId: currentUserId,
            ))
            ..add(FellowshipMembersLoadRequested(
              fellowshipId: widget.fellowshipId,
            )),
        ),
        BlocProvider<FellowshipStudyBloc>(
          create: (_) => sl<FellowshipStudyBloc>()
            ..add(FellowshipStudyInitialized(
              fellowshipId: widget.fellowshipId,
              isMentor: isMentor,
              currentLearningPathId: fellowship?.currentStudy?.learningPathId,
              currentPathTitle: fellowship?.currentStudy?.learningPathTitle,
              currentGuideIndex: fellowship?.currentStudy?.currentGuideIndex,
            ))
            ..add(const FellowshipStudyRefreshRequested()),
        ),
        BlocProvider<LearningPathsBloc>(
          create: (_) {
            final bloc = sl<LearningPathsBloc>();
            final pathId = fellowship?.currentStudy?.learningPathId;
            if (pathId != null) {
              bloc.add(
                  LoadLearningPathDetails(pathId: pathId, forceRefresh: true));
            }
            return bloc;
          },
        ),
        BlocProvider<FellowshipMeetingsBloc>(
          create: (_) => sl<FellowshipMeetingsBloc>()
            ..add(FellowshipMeetingsLoadRequested(widget.fellowshipId)),
        ),
      ],
      child: _FellowshipHomeContent(
        fellowshipId: widget.fellowshipId,
        fellowshipName: widget.fellowshipName,
        fellowship: widget.fellowship,
        isMentor: isMentor,
      ),
    );
  }
}

// ============================================================================
// Inner content — no tabs, single-page scroll design
// ============================================================================

class _FellowshipHomeContent extends StatelessWidget {
  final String fellowshipId;
  final String? fellowshipName;
  final FellowshipEntity? fellowship;
  final bool isMentor;

  const _FellowshipHomeContent({
    required this.fellowshipId,
    required this.isMentor,
    this.fellowshipName,
    this.fellowship,
  });

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _openMembers(BuildContext context) {
    final membersBloc = context.read<FellowshipMembersBloc>();
    final pathsBloc = context.read<LearningPathsBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: membersBloc),
            BlocProvider.value(value: pathsBloc),
          ],
          child: _FellowshipMembersPage(
            fellowshipId: fellowshipId,
            isMentor: isMentor,
          ),
        ),
      ),
    );
  }

  void _openFullFeed(BuildContext context) {
    final feedBloc = context.read<FellowshipFeedBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: feedBloc,
          child: _FellowshipFullFeedPage(fellowshipId: fellowshipId),
        ),
      ),
    );
  }

  void _openLessons(BuildContext context) {
    final studyBloc = context.read<FellowshipStudyBloc>();
    final membersBloc = context.read<FellowshipMembersBloc>();
    final pathsBloc = context.read<LearningPathsBloc>();
    final feedBloc = context.read<FellowshipFeedBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: studyBloc),
            BlocProvider.value(value: membersBloc),
            BlocProvider.value(value: pathsBloc),
            BlocProvider.value(value: feedBloc),
          ],
          child: _FellowshipLessonsPage(fellowshipId: fellowshipId),
        ),
      ),
    );
  }

  void _openMeetings(BuildContext context) {
    final meetingsBloc = context.read<FellowshipMeetingsBloc>();
    // Use the prop OR the BLoC's derived value — the BLoC re-derives isMentor
    // from the loaded member list, which self-corrects when the fellowship
    // entity was unavailable (e.g. deep link / web page refresh).
    final effectiveIsMentor =
        isMentor || context.read<FellowshipMembersBloc>().state.isMentor;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: meetingsBloc,
          child: _FellowshipMeetingsPage(
            fellowshipId: fellowshipId,
            isMentor: effectiveIsMentor,
          ),
        ),
      ),
    );
  }

  // ── Dialogs / sheets ────────────────────────────────────────────────────

  void _showLeaveConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.leaveFellowshipTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          l10n.leaveFellowshipConfirm,
          style:
              TextStyle(fontFamily: 'Inter', color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<FellowshipMembersBloc>()
                  .add(const FellowshipLeaveRequested());
            },
            child: Text(
              l10n.leaveFellowshipTitle,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final bloc = context.read<FellowshipMembersBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _EditFellowshipSheet(initialName: fellowshipName ?? ''),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = (fellowshipName != null && fellowshipName!.isNotEmpty)
        ? fellowshipName!
        : l10n.fellowshipDefaultTitle;

    return MultiBlocListener(
      listeners: [
        BlocListener<FellowshipStudyBloc, FellowshipStudyState>(
          listenWhen: (prev, curr) =>
              prev.currentLearningPathId != curr.currentLearningPathId &&
              curr.currentLearningPathId != null,
          listener: (context, state) {
            context.read<LearningPathsBloc>().add(
                  LoadLearningPathDetails(pathId: state.currentLearningPathId!),
                );
          },
        ),
        BlocListener<FellowshipMembersBloc, FellowshipMembersState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.errorMessage != curr.errorMessage ||
              prev.editStatus != curr.editStatus ||
              prev.transferStatus != curr.transferStatus,
          listener: (context, state) {
            // Left the fellowship — navigate back.
            if (state.status == FellowshipMembersStatus.success &&
                state.members.isEmpty &&
                !isMentor) {
              context.go('/community');
            }
            // Mentor transferred — navigate back.
            if (state.transferStatus == FellowshipTransferStatus.success) {
              context.go('/community');
            }
            // Edit success snackbar.
            if (state.editStatus == FellowshipEditStatus.success) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(l10n.editFellowshipSuccess),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ));
            }
            // Edit failure snackbar.
            if (state.editStatus == FellowshipEditStatus.failure &&
                state.editError != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.editError!),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ));
            }
            // Generic error snackbar.
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ));
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: context.appScaffold,
        appBar: AppBar(
          backgroundColor: context.appScaffold,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          actions: [
            // Members icon
            IconButton(
              icon: Icon(Icons.people_outline_rounded,
                  color: context.appTextPrimary),
              tooltip: l10n.fellowshipTabMembers,
              onPressed: () => _openMembers(context),
            ),
            // Overflow menu (edit / leave)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.appTextPrimary),
              onSelected: (value) {
                if (value == 'leave') _showLeaveConfirm(context);
                if (value == 'edit') _showEditSheet(context);
              },
              itemBuilder: (_) => [
                if (isMentor)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined,
                          color: context.appTextPrimary, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.editFellowshipTitle,
                          style: TextStyle(color: context.appTextPrimary)),
                    ]),
                  ),
                if (!isMentor)
                  PopupMenuItem(
                    value: 'leave',
                    child: Row(children: [
                      const Icon(Icons.exit_to_app,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.leaveFellowshipTitle,
                          style: const TextStyle(color: AppColors.error)),
                    ]),
                  ),
              ],
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            // Gradient hero header
            SliverToBoxAdapter(
              child: _HeroHeader(
                fellowship: fellowship,
                isMentor: isMentor,
                onLessonTap: () => _openLessons(context),
              ),
            ),
            // Meetings tile
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _MeetingsSectionTile(
                  fellowshipId: fellowshipId,
                  isMentor: isMentor,
                  onViewAll: () => _openMeetings(context),
                ),
              ),
            ),
            // Divider
            SliverToBoxAdapter(
              child: Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: context.appDivider,
              ),
            ),
            // Feed preview
            SliverToBoxAdapter(
              child: _FeedPreviewSection(
                fellowshipId: fellowshipId,
                onViewAll: () => _openFullFeed(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Hero header — brand gradient bg with mentor, study chip, progress bar
// ============================================================================

class _HeroHeader extends StatelessWidget {
  final FellowshipEntity? fellowship;
  final bool isMentor;
  final VoidCallback onLessonTap;

  const _HeroHeader({
    required this.isMentor,
    required this.onLessonTap,
    this.fellowship,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mentor name + member count (from members BLoC) ────────────
          BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
            buildWhen: (prev, curr) => prev.members != curr.members,
            builder: (ctx, membersState) {
              final mentor = membersState.members
                  .where((m) => m.role == 'mentor')
                  .firstOrNull;
              final memberCount = membersState.members.isNotEmpty
                  ? membersState.members.length
                  : (fellowship?.memberCount ?? 0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mentor != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.person_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Mentor: ${mentor.displayName}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ]),
                    ),
                  Row(children: [
                    const Icon(Icons.people_outline_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount members',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ]),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Study chip & progress — driven by FellowshipStudyBloc ──────
          // Reads live BLoC state so it works even when `fellowship` entity
          // is unavailable (e.g. hard reload / direct URL navigation).
          BlocBuilder<FellowshipStudyBloc, FellowshipStudyState>(
            buildWhen: (prev, curr) =>
                prev.currentLearningPathId != curr.currentLearningPathId ||
                prev.currentPathTitle != curr.currentPathTitle ||
                prev.currentGuideIndex != curr.currentGuideIndex ||
                prev.totalGuides != curr.totalGuides,
            builder: (ctx, studyState) {
              if (studyState.currentLearningPathId != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tappable chip → opens lessons
                    GestureDetector(
                      onTap: onLessonTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${studyState.currentPathTitle ?? 'Study'} · Lesson ${(studyState.currentGuideIndex ?? 0) + 1}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white70, size: 12),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Progress bar — falls back to LearningPathsBloc topic
                    // count when totalGuides is not yet known from advance.
                    BlocBuilder<LearningPathsBloc, LearningPathsState>(
                      builder: (ctx, pathsState) {
                        final guideIndex = studyState.currentGuideIndex ?? 0;
                        int? total = studyState.totalGuides;
                        if (total == null &&
                            pathsState is LearningPathDetailLoaded) {
                          final count = pathsState.pathDetail.topics.length;
                          if (count > 0) total = count;
                        }
                        final progressValue = (total != null && total > 0)
                            ? (guideIndex + 1) / total
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text(
                                'Group Progress',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              if (total != null)
                                Text(
                                  'Lesson ${guideIndex + 1} of $total',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              } else {
                // No study — mentor sees prompt, member sees placeholder
                return GestureDetector(
                  onTap: isMentor ? onLessonTap : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.library_books_outlined,
                          color: Colors.white60, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        isMentor
                            ? 'Tap to assign a learning path'
                            : 'No learning path assigned yet',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      if (isMentor) ...[
                        const Spacer(),
                        const Icon(Icons.add_circle_outline,
                            color: Colors.white60, size: 18),
                      ],
                    ]),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Feed preview section — 3-5 latest posts + View All
// ============================================================================

class _FeedPreviewSection extends StatelessWidget {
  final String fellowshipId;
  final VoidCallback onViewAll;

  const _FeedPreviewSection({
    required this.fellowshipId,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),

          BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
            builder: (context, state) {
              // Loading
              if ((state.status == FellowshipFeedStatus.initial ||
                      state.status == FellowshipFeedStatus.loading) &&
                  state.posts.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                );
              }

              // Error
              if (state.status == FellowshipFeedStatus.failure &&
                  state.posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 36, color: context.appTextTertiary),
                      const SizedBox(height: 8),
                      Text(
                        l10n.feedLoadError,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            color: context.appTextSecondary),
                      ),
                    ]),
                  ),
                );
              }

              // Empty
              if (state.posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 36, color: context.appTextTertiary),
                      const SizedBox(height: 8),
                      Text(
                        l10n.feedEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onViewAll,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Post something'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ]),
                  ),
                );
              }

              // Posts
              final preview = state.posts.take(5).toList();
              return Column(children: [
                for (final post in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FellowshipPostCard(
                      post: post,
                      fellowshipId: fellowshipId,
                      interactive: false,
                      maxContentLines: 3,
                    ),
                  ),
                // "View all" button when there are more
                if (state.posts.length >= 5 || state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onViewAll,
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: const Text('View All Posts'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-page wrappers — thin Scaffold shells that share parent BLoCs
// ============================================================================

class _FellowshipFullFeedPage extends StatelessWidget {
  final String fellowshipId;

  const _FellowshipFullFeedPage({required this.fellowshipId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.fellowshipTabFeed,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: FellowshipFeedTabScreen(fellowshipId: fellowshipId),
    );
  }
}

class _FellowshipLessonsPage extends StatelessWidget {
  final String fellowshipId;

  const _FellowshipLessonsPage({required this.fellowshipId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.fellowshipTabLessons,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: FellowshipLessonsTabScreen(fellowshipId: fellowshipId),
    );
  }
}

class _FellowshipMembersPage extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;

  const _FellowshipMembersPage({
    required this.fellowshipId,
    required this.isMentor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.fellowshipTabMembers,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: FellowshipMembersTabScreen(fellowshipId: fellowshipId),
    );
  }
}

class _FellowshipMeetingsPage extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;

  const _FellowshipMeetingsPage({
    required this.fellowshipId,
    required this.isMentor,
  });

  void _showScheduleSheet(BuildContext context) {
    final bloc = context.read<FellowshipMeetingsBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: ScheduleMeetingSheet(fellowshipId: fellowshipId),
      ),
    );
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
          'Meetings',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      floatingActionButton: isMentor
          ? FloatingActionButton.extended(
              onPressed: () => _showScheduleSheet(context),
              backgroundColor: context.appInteractive,
              foregroundColor: AppColors.onGradient,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Schedule',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: FellowshipMeetingsTabScreen(
        fellowshipId: fellowshipId,
        isMentor: isMentor,
      ),
    );
  }
}

// ============================================================================
// Meetings section tile — home screen navigation card
// ============================================================================

class _MeetingsSectionTile extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;
  final VoidCallback onViewAll;

  const _MeetingsSectionTile({
    required this.fellowshipId,
    required this.isMentor,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: onViewAll,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: BlocBuilder<FellowshipMeetingsBloc, FellowshipMeetingsState>(
            builder: (context, state) {
              final next =
                  state.meetings.isNotEmpty ? state.meetings.first : null;
              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          AppColors.brandPrimaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_call_rounded,
                      color: AppColors.brandPrimaryLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meetings',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          next != null
                              ? () {
                                  final dt = DateTime.tryParse(next.startsAt)
                                      ?.toLocal();
                                  if (dt == null) return 'Next: ${next.title}';
                                  final h =
                                      dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                                  final m =
                                      dt.minute.toString().padLeft(2, '0');
                                  final ampm = dt.hour < 12 ? 'AM' : 'PM';
                                  return 'Next: ${next.title} · $h:$m $ampm';
                                }()
                              : (isMentor
                                  ? 'Schedule a meeting'
                                  : 'No upcoming meetings'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: context.appTextTertiary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Edit Fellowship bottom sheet (unchanged from previous implementation)
// ============================================================================

class _EditFellowshipSheet extends StatefulWidget {
  final String initialName;

  const _EditFellowshipSheet({required this.initialName});

  @override
  State<_EditFellowshipSheet> createState() => _EditFellowshipSheetState();
}

class _EditFellowshipSheetState extends State<_EditFellowshipSheet> {
  late final TextEditingController _nameCtrl;
  final TextEditingController _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<FellowshipMembersBloc, FellowshipMembersState>(
      listenWhen: (prev, curr) => prev.editStatus != curr.editStatus,
      listener: (context, state) {
        if (state.editStatus == FellowshipEditStatus.success) {
          Navigator.of(context).pop();
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
                    l10n.editFellowshipTitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Name field
                  TextFormField(
                    controller: _nameCtrl,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: l10n.createFellowshipNameLabel,
                      filled: true,
                      fillColor: context.appInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return l10n.createFellowshipNameError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Description field
                  TextFormField(
                    controller: _descCtrl,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.createFellowshipDescLabel,
                      filled: true,
                      fillColor: context.appInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Save button
                  BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
                    buildWhen: (prev, curr) =>
                        prev.editStatus != curr.editStatus,
                    builder: (context, state) {
                      final loading =
                          state.editStatus == FellowshipEditStatus.loading;
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  context
                                      .read<FellowshipMembersBloc>()
                                      .add(FellowshipEditRequested(
                                        name: _nameCtrl.text.trim(),
                                        description:
                                            _descCtrl.text.trim().isNotEmpty
                                                ? _descCtrl.text.trim()
                                                : null,
                                      ));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
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
                                  l10n.editFellowshipSave,
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
