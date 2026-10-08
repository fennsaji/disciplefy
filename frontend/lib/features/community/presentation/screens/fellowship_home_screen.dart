import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/features/community/domain/utils/fellowship_lesson_language.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_meeting_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_meetings/fellowship_meetings_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_feed_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_lessons_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_meetings_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_members_tab_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_post_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/schedule_meeting_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/auth_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/feed_sort.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/share_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/group_study_progress.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_confirm_dialog.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_comments_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_report_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mentor_contact_sheet.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/models/user_profile_model.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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

  /// When set (post deep link), the full feed is pushed and this post's
  /// comments are opened once the first feed load succeeds.
  final String? initialPostId;

  const FellowshipHomeScreen({
    required this.fellowshipId,
    this.fellowshipName,
    this.fellowship,
    this.initialPostId,
    super.key,
  });

  @override
  State<FellowshipHomeScreen> createState() => _FellowshipHomeScreenState();
}

class _FellowshipHomeScreenState extends State<FellowshipHomeScreen> {
  bool _handledInitialPost = false;

  /// The fellowship loaded by id when no entity came with the navigation
  /// (Home banner, activity row, deep link, notification, post back-nav).
  FellowshipEntity? _loadedFellowship;

  FellowshipEntity? get _fellowship => widget.fellowship ?? _loadedFellowship;

  @override
  void initState() {
    super.initState();
    if (widget.fellowship == null) _loadFellowship();
  }

  /// Fetches the caller's fellowships (deduped in-flight by the repository,
  /// shared with Home/Community) and picks this one, so entity-only fields
  /// (role, daily post / discipler flags, name, mentors) match the
  /// Community-list entry.
  Future<void> _loadFellowship() async {
    if (!sl.isRegistered<CommunityRepository>() ||
        !sl.isRegistered<LanguagePreferenceService>()) {
      return;
    }
    final lang =
        await sl<LanguagePreferenceService>().getStudyContentLanguage();
    final result = await sl<CommunityRepository>().getFellowships(lang.code);
    if (!mounted) return;
    result.fold((_) {}, (list) {
      for (final f in list) {
        if (f.id == widget.fellowshipId) {
          setState(() => _loadedFellowship = f);
          return;
        }
      }
    });
  }

  void _handleFeedStateChange(BuildContext context, FellowshipFeedState state) {
    if (widget.initialPostId == null || _handledInitialPost) return;
    if (state.status != FellowshipFeedStatus.success) return;
    _handledInitialPost = true;
    final feedBloc = context.read<FellowshipFeedBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: feedBloc,
          child: FellowshipPostDetailScreen(
            fellowshipId: widget.fellowshipId,
            fellowshipName: widget.fellowshipName ?? _fellowship?.name,
            postId: widget.initialPostId!,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fellowship = _fellowship;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMentor = fellowship?.userRole == 'mentor';
    return MultiBlocProvider(
      providers: [
        BlocProvider<FellowshipFeedBloc>(
          create: (_) => sl<FellowshipFeedBloc>()
            ..add(FellowshipFeedInitialized(
              isMentor: isMentor,
              currentUserId: currentUserId,
              postingPermission: fellowship?.postingPermission ?? 'all_members',
              // Known immediately when the entity was passed; otherwise wait
              // for the server (avoids flashing the post button on refresh).
              postingContextResolved: fellowship != null,
              disciplerAllowed: fellowship?.disciplerAllowed ?? false,
              mentors: fellowship?.mentors ?? const [],
            ))
            // Authoritative posting context — corrects FAB/empty-state gating
            // when the entity wasn't passed (deep link / web refresh).
            ..add(FellowshipFeedContextRequested(
              fellowshipId: widget.fellowshipId,
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
              currentTotalGuides: fellowship?.currentStudy?.totalGuides,
              studyCompleted: fellowship?.currentStudy?.completedAt != null,
            ))
            ..add(const FellowshipStudyRefreshRequested()),
        ),
        BlocProvider<LearningPathsBloc>(
          create: (_) => sl<LearningPathsBloc>(),
        ),
        BlocProvider<FellowshipMeetingsBloc>(
          create: (_) => sl<FellowshipMeetingsBloc>()
            ..add(FellowshipMeetingsLoadRequested(widget.fellowshipId)),
        ),
      ],
      child: BlocListener<FellowshipFeedBloc, FellowshipFeedState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _handleFeedStateChange,
        child: _ResolvedRole(
          seedIsMentor: isMentor,
          builder: (resolvedIsMentor) => _FellowshipHomeContent(
            fellowshipId: widget.fellowshipId,
            fellowshipName: widget.fellowshipName ?? fellowship?.name,
            fellowship: fellowship,
            isMentor: resolvedIsMentor,
          ),
        ),
      ),
    );
  }
}

/// Resolves the caller's mentor role for the fellowship screen.
///
/// The navigation extra (FellowshipEntity) only exists when the group is
/// opened from the Community list. From Home, a deep link, a notification or
/// post-detail back navigation the screen gets only an id, so the seed is
/// false. The feed bloc (server `caller_role`) and the members bloc (loaded
/// member list) resolve the real role; either one marking the caller as a
/// mentor wins. The study bloc is kept in sync for the lessons page.
class _ResolvedRole extends StatelessWidget {
  final bool seedIsMentor;
  final Widget Function(bool isMentor) builder;

  const _ResolvedRole({required this.seedIsMentor, required this.builder});

  @override
  Widget build(BuildContext context) {
    final feedIsMentor =
        context.select((FellowshipFeedBloc b) => b.state.isMentor);
    final membersIsMentor =
        context.select((FellowshipMembersBloc b) => b.state.isMentor);
    final isMentor = seedIsMentor || feedIsMentor || membersIsMentor;
    final studyBloc = context.read<FellowshipStudyBloc>();
    if (studyBloc.state.isMentor != isMentor) {
      studyBloc.add(FellowshipStudyRoleResolved(isMentor: isMentor));
    }
    return builder(isMentor);
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
            fellowshipName: fellowshipName,
            disciplerAllowed: fellowship?.disciplerAllowed ?? false,
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
          child: _FellowshipFullFeedPage(
            fellowshipId: fellowshipId,
            fellowshipName: fellowshipName,
          ),
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

  Future<void> _showLeaveConfirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final membersBloc = context.read<FellowshipMembersBloc>();
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: Icons.exit_to_app,
      title: l10n.leaveFellowshipTitle,
      body: l10n.leaveFellowshipConfirm,
      confirmLabel: l10n.leaveFellowshipTitle,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed) membersBloc.add(const FellowshipLeaveRequested());
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final membersBloc = context.read<FellowshipMembersBloc>();
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: Icons.delete_outline,
      title: l10n.deleteFellowshipTitle,
      body: l10n.deleteFellowshipConfirm,
      confirmLabel: l10n.deleteFellowshipTitle,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed) membersBloc.add(const FellowshipDeleteRequested());
  }

  /// Back to wherever the fellowship was opened from, or to the Community
  /// tab when it was the first page (deep link, web refresh).
  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/community');
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final membersBloc = context.read<FellowshipMembersBloc>();
    await context.push<void>('/community/$fellowshipId/settings',
        extra: fellowship);
    if (context.mounted) {
      membersBloc
          .add(FellowshipMembersLoadRequested(fellowshipId: fellowshipId));
    }
  }

  Widget _buildOverflowMenu(BuildContext context, AppLocalizations l10n) {
    final palette = ReaderPalette.of(context);
    final errorColor =
        palette.isDark ? AppColors.errorLighter : AppColors.errorDark;
    PopupMenuItem<String> item(String value, IconData icon, String label,
            {bool destructive = false}) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(children: [
            Icon(icon,
                color: destructive ? errorColor : palette.text, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 15,
                  color: destructive ? errorColor : palette.text,
                ),
              ),
            ),
          ]),
        );
    final muted = fellowship?.myNotificationsMuted ?? false;
    return PopupMenuButton<String>(
      tooltip: context.tr(TranslationKeys.communitySharedMoreOptions),
      icon: Icon(Icons.more_vert, color: palette.text),
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.hairline),
      ),
      onSelected: (value) async {
        if (value == 'leave') await _showLeaveConfirm(context);
        if (value == 'settings') await _openSettings(context);
        if (value == 'discipler_activity') {
          if (!context.mounted) return;
          context.push('/community/$fellowshipId/discipler-activity');
        }
        if (value == 'daily_post') {
          if (!context.mounted) return;
          context.push('/community/$fellowshipId/daily-post');
        }
        if (value == 'mute_notifications') {
          if (!context.mounted) return;
          await _toggleMuteNotifications(context, fellowshipId, !muted);
        }
        if (value == 'delete') {
          if (!context.mounted) return;
          await _showDeleteConfirm(context);
        }
      },
      itemBuilder: (_) => [
        if (isMentor)
          item('settings', Icons.settings_outlined,
              l10n.fellowshipSettingsTitle),
        if (isMentor && (fellowship?.dailyPostAllowed ?? false))
          item('daily_post', Icons.event_note_outlined,
              l10n.dailyPostScreenTitle),
        // Daily posts show up in the activity list too, so groups with
        // only daily posts need it to review and edit them.
        if (isMentor &&
            ((fellowship?.disciplerAllowed ?? false) ||
                (fellowship?.dailyPostAllowed ?? false)))
          item('discipler_activity', Icons.auto_awesome_rounded,
              l10n.disciplerActivityTitle),
        item(
          'mute_notifications',
          muted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          muted
              ? l10n.fellowshipUnmuteNotifications
              : l10n.fellowshipMuteNotifications,
        ),
        if (isMentor)
          item('delete', Icons.delete_outline, l10n.deleteFellowshipTitle,
              destructive: true),
        if (!isMentor)
          item('leave', Icons.exit_to_app, l10n.leaveFellowshipTitle,
              destructive: true),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    // Opened with only an id (invite or deep link): use the loaded name.
    final loadedName =
        context.select((FellowshipStudyBloc b) => b.state.fellowshipName);
    final name = (fellowshipName != null && fellowshipName!.isNotEmpty)
        ? fellowshipName
        : loadedName;
    final title =
        (name != null && name.isNotEmpty) ? name : l10n.fellowshipDefaultTitle;

    return MultiBlocListener(
      listeners: [
        BlocListener<FellowshipMembersBloc, FellowshipMembersState>(
          listenWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.errorMessage != curr.errorMessage ||
              prev.editStatus != curr.editStatus ||
              prev.transferStatus != curr.transferStatus ||
              prev.leaveStatus != curr.leaveStatus ||
              prev.deleteStatus != curr.deleteStatus,
          listener: (context, state) {
            // Left the fellowship — navigate back to list.
            if (state.leaveStatus == FellowshipLeaveStatus.success) {
              context.go('/community');
            }
            // Mentor transferred — navigate back.
            if (state.transferStatus == FellowshipTransferStatus.success) {
              context.go('/community');
            }
            // Fellowship deleted — navigate back and show confirmation.
            if (state.deleteStatus == FellowshipDeleteStatus.success) {
              context.go('/community');
              showAppSnackBar(context, l10n.deleteFellowshipSuccess,
                  tone: AppSnackTone.success);
            }
            if (state.deleteStatus == FellowshipDeleteStatus.failure &&
                state.errorMessage != null) {
              showAppSnackBar(context, state.errorMessage!,
                  tone: AppSnackTone.error);
            }
            // Edit success snackbar.
            if (state.editStatus == FellowshipEditStatus.success) {
              showAppSnackBar(context, l10n.editFellowshipSuccess,
                  tone: AppSnackTone.success);
            }
            // Edit failure snackbar.
            if (state.editStatus == FellowshipEditStatus.failure &&
                state.editError != null) {
              showAppSnackBar(context, state.editError!,
                  tone: AppSnackTone.error);
            }
            // Generic error snackbar.
            if (state.errorMessage != null) {
              showAppSnackBar(context, state.errorMessage!,
                  tone: AppSnackTone.error);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: palette.page,
        floatingActionButton:
            BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
          buildWhen: (prev, curr) =>
              prev.canShowPostButton != curr.canShowPostButton,
          builder: (context, feedState) {
            if (!feedState.canShowPostButton) return const SizedBox.shrink();
            return CommunityCtaPill(
              large: true,
              icon: Icons.add,
              label: l10n.feedNewPost,
              onPressed: () {
                final feedBloc = context.read<FellowshipFeedBloc>();
                showModalBottomSheet<void>(
                  useRootNavigator: true,
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BlocProvider.value(
                    value: feedBloc,
                    child:
                        FellowshipCreatePostSheet(fellowshipId: fellowshipId),
                  ),
                );
              },
            );
          },
        ),
        // Only this screen (with My fellowships and Discover) carries the
        // photo wash; each fellowship keeps its own tint.
        body: PhotoWash.forKey(
          photoKey: fellowshipId,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CommunityBackBar(
                  onBack: () => _goBack(context),
                  actions: [
                    CommunityIconAction(
                      icon: Icons.people_outline_rounded,
                      tooltip: l10n.fellowshipTabMembers,
                      onPressed: () => _openMembers(context),
                    ),
                    _buildOverflowMenu(context, l10n),
                  ],
                ),
              ),
              // Meta line, name and the mentor / invite actions
              SliverToBoxAdapter(
                child: _HeroHeader(
                  fellowshipId: fellowshipId,
                  fellowshipName: fellowshipName,
                  title: title,
                  fellowship: fellowship,
                  isMentor: isMentor,
                  onOpenSettings: () => _openSettings(context),
                ),
              ),
              // Studying together
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _StudyingTogetherCard(
                    isMentor: isMentor,
                    onLessonTap: () => _openLessons(context),
                  ),
                ),
              ),
              // Next meeting (hidden for members when none is scheduled)
              SliverToBoxAdapter(
                child: _MeetingsSectionTile(
                  isMentor: isMentor,
                  onViewAll: () => _openMeetings(context),
                ),
              ),
              // Feed preview
              SliverToBoxAdapter(
                child: _FeedPreviewSection(
                  fellowshipId: fellowshipId,
                  fellowshipName: fellowshipName,
                  onViewAll: () => _openFullFeed(context),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Hero header — gold meta line, fellowship name, mentor / invite actions
// ============================================================================

class _HeroHeader extends StatelessWidget {
  final String fellowshipId;
  final String? fellowshipName;
  final String title;
  final FellowshipEntity? fellowship;
  final bool isMentor;
  final VoidCallback onOpenSettings;

  const _HeroHeader({
    required this.fellowshipId,
    required this.title,
    required this.isMentor,
    required this.onOpenSettings,
    this.fellowshipName,
    this.fellowship,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
      // isMentor as well as members: the invite button below depends on it,
      // and it is re-derived from the roster after load — so on a deep link,
      // where the navigation extra is absent and the seed is false, the
      // button must appear once the roster proves the viewer mentors this
      // group.
      child: BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        buildWhen: (prev, curr) =>
            prev.members != curr.members || prev.isMentor != curr.isMentor,
        builder: (ctx, membersState) {
          final l10n = AppLocalizations.of(context)!;
          final mentorMembers =
              membersState.members.where((m) => m.role == 'mentor').toList();
          final mentorsWithContact = mentorMembers
              .where((m) =>
                  (m.mentorWhatsapp?.isNotEmpty ?? false) ||
                  (m.mentorEmail?.isNotEmpty ?? false))
              .toList();
          final mentorIds = mentorMembers.isNotEmpty
              ? mentorMembers.map((m) => m.userId)
              : (fellowship?.mentors.map((m) => m.userId) ?? const <String>[]);
          // Official and Discipler-mentored groups read "Guided by
          // Discipler", the same as their card on the Community tab.
          final guidedByDiscipler = fellowship?.isOfficial == true ||
              mentorIds.contains(kDisciplerUserId);
          final mentorNames = guidedByDiscipler
              ? ''
              : (mentorMembers.isNotEmpty
                      ? mentorMembers.map((m) => m.displayName)
                      : (fellowship?.mentors.map((m) => m.displayName) ??
                          const <String>[]))
                  .map(realMentorName)
                  .whereType<String>()
                  .join(', ');
          final memberCount = membersState.members.isNotEmpty
              ? membersState.members.length
              : (fellowship?.memberCount ?? 0);

          final meta = [
            if (fellowship?.isOfficial == true) l10n.officialBadge,
            '$memberCount ${l10n.communityMembersCount(memberCount)}',
            if (guidedByDiscipler)
              context.tr(TranslationKeys.communityGuidedByDiscipler)
            else if (mentorNames.isNotEmpty)
              context.tr(
                  TranslationKeys.communitySharedMentor, {'name': mentorNames}),
          ].join(' · ');

          final canInvite = isMentor || membersState.isMentor;
          // A mentor who has not opened the private channel yet gets a quiet
          // prompt in place of the member-facing button: without it the
          // setting is only discoverable by scrolling through fellowship
          // settings, so existing groups would never adopt it. Members never
          // see this.
          final showContactPrompt = mentorsWithContact.isEmpty && isMentor;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunitySectionLabel(meta),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (showContactPrompt ||
                  mentorsWithContact.isNotEmpty ||
                  canInvite) ...[
                const SizedBox(height: 8),
                // Wrap, not Row: these labels are far longer in Hindi and
                // Malayalam, and a Row has no way to give way. Wrapping puts
                // the next pill on its own line instead; each pill's label
                // wraps too when it is wider than the screen.
                Wrap(spacing: 8, children: [
                  if (showContactPrompt)
                    CommunityRaisedPill(
                      icon: Icons.alternate_email_rounded,
                      label: l10n.mentorContactPrompt,
                      onPressed: onOpenSettings,
                    ),
                  if (mentorsWithContact.isNotEmpty)
                    CommunityRaisedPill(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: l10n.messageMentor,
                      onPressed: () => showMentorContactSheet(
                        context,
                        mentorsWithContact: mentorsWithContact,
                        fellowshipName: (fellowshipName != null &&
                                fellowshipName!.isNotEmpty)
                            ? fellowshipName!
                            : l10n.fellowshipDefaultTitle,
                      ),
                    ),
                  // Only a mentor may invite: creating an invite is refused
                  // server-side for anyone else (fellowship-invites checks
                  // is_fellowship_mentor and returns 403). The seed can be
                  // false on a deep link, so take the roster's answer too.
                  if (canInvite)
                    CommunityRaisedPill(
                      icon: Icons.person_add_alt_1_outlined,
                      label: l10n.fellowshipInviteMembers,
                      onPressed: () => shareFellowshipInvite(
                          context, fellowshipId, fellowshipName),
                    ),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// Studying together — current lesson + group progress, opens the lessons
// ============================================================================

class _StudyingTogetherCard extends StatelessWidget {
  final bool isMentor;
  final VoidCallback onLessonTap;

  const _StudyingTogetherCard({
    required this.isMentor,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Reads live BLoC state so it works even when the fellowship entity is
    // unavailable (e.g. hard reload / direct URL navigation).
    return BlocBuilder<FellowshipStudyBloc, FellowshipStudyState>(
      buildWhen: (prev, curr) =>
          prev.currentLearningPathId != curr.currentLearningPathId ||
          prev.currentPathTitle != curr.currentPathTitle ||
          prev.currentGuideIndex != curr.currentGuideIndex ||
          prev.totalGuides != curr.totalGuides ||
          prev.studyCompleted != curr.studyCompleted,
      builder: (ctx, studyState) {
        final l10n = AppLocalizations.of(context)!;
        if (studyState.currentLearningPathId == null) {
          // No study — mentor sees an assign prompt, member a placeholder.
          return FellowshipCardShell(
            onTap: isMentor ? onLessonTap : null,
            child: Row(children: [
              Icon(Icons.library_books_outlined,
                  color: palette.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isMentor
                      ? l10n.homeAssignPathMentor
                      : l10n.homeNoPathAssigned,
                  style: AppFonts.inter(
                    fontSize: 15,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ),
              if (isMentor) ...[
                const SizedBox(width: 8),
                Icon(Icons.add_circle_outline,
                    color: palette.accentIcon, size: 22),
              ],
            ]),
          );
        }

        final guideIndex = studyState.currentGuideIndex ?? 0;
        final lesson = context.tr(
            TranslationKeys.communitySharedLesson, {'number': guideIndex + 1});
        final path = studyState.currentPathTitle?.trim();
        final hasPath = path != null && path.isNotEmpty;
        // A finished path is named on its own; the progress line below says
        // it is finished.
        final heading = studyState.studyCompleted
            ? (hasPath ? path : l10n.lessonsCompleted)
            : hasPath
                ? '$path · $lesson'
                : lesson;

        return FellowshipCardShell(
          onTap: onLessonTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CommunitySectionLabel(context.tr(
                        TranslationKeys.communityFellowshipStudyingTogether)),
                  ),
                  const SizedBox(width: 12),
                  // Natural width so the label keeps its line; a long
                  // translation wraps inside the cap instead.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      l10n.fellowshipViewLessons,
                      textAlign: TextAlign.end,
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.accentIcon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                heading,
                style: AppFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.35,
                ),
              ),
              // Progress bar — falls back to LearningPathsBloc topic count
              // when totalGuides is not yet known from advance.
              BlocBuilder<LearningPathsBloc, LearningPathsState>(
                builder: (ctx, pathsState) {
                  int? total = studyState.totalGuides;
                  // The loaded lessons, when they are this group's path.
                  if ((total == null || total <= 0) &&
                      pathsState is LearningPathDetailLoaded &&
                      pathsState.pathDetail.id ==
                          studyState.currentLearningPathId) {
                    final count = pathsState.pathDetail.topics.length;
                    if (count > 0) total = count;
                  }
                  final progress = GroupStudyProgress.of(
                    currentGuideIndex: guideIndex,
                    totalGuides: total,
                    completed: studyState.studyCompleted,
                  );
                  final groupProgress = context
                      .tr(TranslationKeys.communityFellowshipGroupProgress);
                  final detail = progress.finishedLabel(context) ??
                      progress.doneLabel(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (progress.fraction != null) ...[
                        CommunityProgressBar(value: progress.fraction!),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        detail != null
                            ? '$groupProgress · $detail'
                            : groupProgress,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Feed preview section — 3-5 latest posts + View All
// ============================================================================

class _FeedPreviewSection extends StatelessWidget {
  final String fellowshipId;
  final String? fellowshipName;
  final VoidCallback onViewAll;

  const _FeedPreviewSection({
    required this.fellowshipId,
    required this.onViewAll,
    this.fellowshipName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CommunitySectionHeader(
              title: l10n.fellowshipRecentActivity,
              actionLabel: l10n.fellowshipViewAll,
              onAction: onViewAll,
            ),
          ),
          const SizedBox(height: 8),
          BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
            builder: (context, state) {
              // Loading
              if ((state.status == FellowshipFeedStatus.initial ||
                      state.status == FellowshipFeedStatus.loading) &&
                  state.posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.accentIcon),
                  ),
                );
              }

              // Opened a shared link to a fellowship the viewer has not
              // joined. Not a failure to report — offer the way in instead.
              if (state.notAMember) {
                return _NotAMemberCard(fellowshipId: fellowshipId);
              }

              // Error
              if (state.status == FellowshipFeedStatus.failure &&
                  state.posts.isEmpty) {
                return _PreviewMessage(
                  icon: Icons.wifi_off_rounded,
                  message: l10n.feedLoadError,
                );
              }

              // Empty
              if (state.posts.isEmpty) {
                return _PreviewMessage(
                  icon: Icons.chat_bubble_outline_rounded,
                  // No "Post something" here: the floating New Post button
                  // is the one way to post.
                  message:
                      state.canPost ? l10n.feedEmpty : l10n.feedEmptyReadOnly,
                );
              }

              // Posts — sorted so today's daily study leads the preview.
              final preview = sortFeed(state.posts).take(5).toList();
              final isAdmin = isViewerAdmin(context);
              return Column(children: [
                for (final post in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FellowshipPostCard(
                      post: post,
                      fellowshipId: fellowshipId,
                      // Same affordances as the feed: the preview shows real
                      // posts, so reacting and replying belong here too.
                      isMentor: state.isMentor,
                      currentUserId: state.currentUserId,
                      maxContentLines: FellowshipPostCard.feedMaxContentLines,
                      isAdmin: isAdmin,
                      onPostTap: () {
                        final bloc = context.read<FellowshipFeedBloc>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: bloc,
                              child: FellowshipPostDetailScreen(
                                fellowshipId: fellowshipId,
                                fellowshipName: fellowshipName,
                                postId: post.id,
                              ),
                            ),
                          ),
                        );
                      },
                      onShareTap: () =>
                          sharePost(context, post, fellowshipName),
                      onCommentTap: () {
                        final bloc = context.read<FellowshipFeedBloc>();
                        bloc.add(
                            FellowshipCommentsOpenRequested(postId: post.id));
                        showModalBottomSheet<void>(
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BlocProvider.value(
                            value: bloc,
                            child: FellowshipCommentsSheet(
                              postId: post.id,
                              fellowshipId: fellowshipId,
                              isMentor: state.isMentor,
                              currentUserId: state.currentUserId,
                            ),
                          ),
                        );
                      },
                      onReportTap: () {
                        final bloc = context.read<FellowshipFeedBloc>();
                        showModalBottomSheet<void>(
                          useRootNavigator: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BlocProvider.value(
                            value: bloc,
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
                  ),
                // "View all" button when there are more
                if (state.posts.length >= 5 || state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Center(
                      child: CommunityRaisedPill(
                        icon: Icons.expand_more_rounded,
                        label: context.tr(
                            TranslationKeys.communityFellowshipViewAllPosts),
                        onPressed: onViewAll,
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

/// Icon, muted message and an optional action, centred — the feed preview's
/// error and empty states.
class _PreviewMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PreviewMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 36, color: palette.dim),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 15,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// Sub-page wrappers — thin Scaffold shells that share parent BLoCs
// ============================================================================

class _FellowshipFullFeedPage extends StatelessWidget {
  final String fellowshipId;
  final String? fellowshipName;

  const _FellowshipFullFeedPage({
    required this.fellowshipId,
    this.fellowshipName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: l10n.fellowshipTabFeed,
        background: palette.page,
      ),
      body: FellowshipFeedTabScreen(
        fellowshipId: fellowshipId,
        fellowshipName: fellowshipName,
      ),
    );
  }
}

class _FellowshipLessonsPage extends StatefulWidget {
  final String fellowshipId;

  const _FellowshipLessonsPage({required this.fellowshipId});

  @override
  State<_FellowshipLessonsPage> createState() => _FellowshipLessonsPageState();
}

class _FellowshipLessonsPageState extends State<_FellowshipLessonsPage> {
  /// The language this member picked for this group's lessons; null means
  /// the group's own language.
  AppLanguage? _selectedLanguage;

  /// Kept per fellowship, and apart from the app-wide study language: reading
  /// a Hindi group's lessons in English should not change every other study.
  String get _languagePrefKey =>
      fellowshipLessonsLanguagePrefKey(widget.fellowshipId);

  @override
  void initState() {
    super.initState();
    final saved = sl<SharedPreferences>().getString(_languagePrefKey);
    if (saved != null) _selectedLanguage = AppLanguage.fromCode(saved);
  }

  Future<void> _showLanguageSelector(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = sl<SharedPreferences>();
    final groupCode =
        context.read<FellowshipStudyBloc>().state.fellowshipLanguage;
    final groupLanguage =
        groupCode == null ? null : AppLanguage.fromCode(groupCode);
    final isDefault = _selectedLanguage == null;

    final palette = ReaderPalette.of(context);
    await showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.tr(TranslationKeys.studyTopicsContentLanguage),
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                        TranslationKeys.studyTopicsContentLanguageDescription),
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(
                l10n.lessonsGroupLanguage,
                style: AppFonts.inter(fontSize: 15, color: palette.text),
              ),
              subtitle: groupLanguage == null
                  ? null
                  : Text(
                      groupLanguage.displayName,
                      style: AppFonts.inter(fontSize: 13, color: palette.muted),
                    ),
              trailing: isDefault
                  ? Icon(Icons.check, color: palette.accentIcon)
                  : null,
              onTap: () async {
                await prefs.remove(_languagePrefKey);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) setState(() => _selectedLanguage = null);
              },
            ),
            Divider(height: 1, color: palette.hairline),
            ...AppLanguage.values.map((language) {
              final isSelected = !isDefault && language == _selectedLanguage;
              return ListTile(
                title: Text(
                  language.displayName,
                  style: AppFonts.inter(fontSize: 15, color: palette.text),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: palette.accentIcon)
                    : null,
                onTap: () async {
                  await prefs.setString(_languagePrefKey, language.code);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) setState(() => _selectedLanguage = language);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showStudyModeSelector(BuildContext context) {
    final authProvider = sl<AuthStateProvider>();
    final currentMode =
        authProvider.userProfile?['learning_path_study_mode'] as String?;
    final parentContext = context;

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: ReaderPalette.of(builderContext).card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SheetScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ReaderPalette.of(builderContext).outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                    TranslationKeys.settingsLearningPathStudyModePreference),
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ReaderPalette.of(builderContext).text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                    TranslationKeys.settingsLearningPathStudyModeDescription),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: ReaderPalette.of(builderContext).muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              _buildLearningPathModeOption(
                builderContext,
                parentContext,
                'recommended',
                context.tr(TranslationKeys.settingsUseRecommended),
                Icons.stars,
                context.tr(TranslationKeys.settingsUseRecommendedSubtitle),
                currentMode,
              ),
              const SizedBox(height: 12),
              _buildLearningPathModeOption(
                builderContext,
                parentContext,
                'ask',
                context.tr(TranslationKeys.settingsAskEveryTime),
                Icons.help_outline,
                context.tr(TranslationKeys.settingsAskEveryTimeSubtitle),
                currentMode,
              ),
              const SizedBox(height: 12),
              Divider(
                  color: ReaderPalette.of(builderContext).hairline, height: 24),
              ...StudyMode.values.map((mode) => Column(
                    children: [
                      _buildLearningPathModeOption(
                        builderContext,
                        parentContext,
                        mode.value,
                        _getStudyModeTranslatedName(mode, context),
                        mode.iconData,
                        '${mode.durationText} • ${_getStudyModeTranslatedDescription(mode, context)}',
                        currentMode,
                      ),
                      const SizedBox(height: 12),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String _getStudyModeTranslatedName(StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickName);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardName);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepName);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioName);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonName);
    }
  }

  String _getStudyModeTranslatedDescription(
      StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickDescription);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardDescription);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepDescription);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioDescription);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonDescription);
    }
  }

  Widget _buildLearningPathModeOption(
    BuildContext sheetContext,
    BuildContext parentContext,
    String value,
    String label,
    IconData icon,
    String subtitle,
    String? currentMode,
  ) {
    final isSelected = value == currentMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            final userProfileService = sl<UserProfileService>();
            final authProvider = sl<AuthStateProvider>();
            final result = await userProfileService
                .updateLearningPathStudyModePreference(value);

            if (parentContext.mounted) {
              result.fold(
                (failure) {
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  showAppSnackBar(
                    parentContext,
                    parentContext.tr(TranslationKeys.errorUpdatingPreference),
                    tone: AppSnackTone.error,
                  );
                },
                (profile) {
                  final userId = authProvider.userId;
                  if (userId != null) {
                    final profileMap =
                        UserProfileModel.fromEntity(profile).toJson();
                    authProvider.cacheProfile(userId, profileMap);
                  }
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  showAppSnackBar(
                    parentContext,
                    parentContext
                        .tr(TranslationKeys.preferenceUpdatedSuccessfully),
                    tone: AppSnackTone.success,
                  );
                },
              );
            }
          } catch (e) {
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            if (parentContext.mounted) {
              showAppSnackBar(
                parentContext,
                parentContext.tr(TranslationKeys.errorUpdatingPreference),
                tone: AppSnackTone.error,
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Builder(builder: (context) {
          final palette = ReaderPalette.of(sheetContext);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.gold.withValues(alpha: palette.isDark ? 0.18 : 0.08)
                  : palette.raised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? palette.accentIcon : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.gold
                            .withValues(alpha: palette.isDark ? 0.28 : 0.12)
                        : palette.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? palette.accentIcon : palette.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? palette.accentIcon : palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: palette.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: palette.accentIcon,
                    size: 22,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showResetConfirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final studyBloc = context.read<FellowshipStudyBloc>();
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: Icons.restart_alt,
      title: l10n.lessonsResetProgress,
      body: l10n.lessonsResetConfirm,
      confirmLabel: l10n.lessonsResetAction,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed) studyBloc.add(const FellowshipStudyResetRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMentor = context.watch<FellowshipStudyBloc>().state.isMentor;
    final palette = ReaderPalette.of(context);
    final errorColor =
        palette.isDark ? AppColors.errorLighter : AppColors.errorDark;
    PopupMenuItem<String> item(String value, IconData icon, String label,
            {bool destructive = false}) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: destructive ? errorColor : palette.text),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 15,
                    color: destructive ? errorColor : palette.text,
                  ),
                ),
              ),
            ],
          ),
        );
    return Scaffold(
      backgroundColor: palette.page,
      // The path title can wrap, so the bar sits in the body and grows.
      body: Column(children: [
        FellowshipLessonsTopBar(
          actions: [
            PopupMenuButton<String>(
              tooltip: context.tr(TranslationKeys.communitySharedMoreOptions),
              icon: Icon(Icons.more_vert, color: palette.text),
              color: palette.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.hairline),
              ),
              onSelected: (value) {
                if (value == 'language') {
                  _showLanguageSelector(context);
                } else if (value == 'study_mode') {
                  _showStudyModeSelector(context);
                } else if (value == 'reset') {
                  _showResetConfirm(context);
                }
              },
              itemBuilder: (_) => [
                item('language', Icons.language,
                    context.tr(TranslationKeys.studyTopicsContentLanguage)),
                item('study_mode', Icons.auto_awesome,
                    context.tr(TranslationKeys.studyModePreferenceTitle)),
                if (isMentor)
                  item('reset', Icons.restart_alt, l10n.lessonsResetProgress,
                      destructive: true),
              ],
            ),
          ],
        ),
        Expanded(
          child: FellowshipLessonsTabScreen(
            fellowshipId: widget.fellowshipId,
            // The member's pick for this group, else the group's language.
            languageOverride: _selectedLanguage?.code ??
                context.watch<FellowshipStudyBloc>().state.fellowshipLanguage,
          ),
        ),
      ]),
    );
  }
}

class _FellowshipMembersPage extends StatelessWidget {
  final String fellowshipId;
  final bool isMentor;
  final String? fellowshipName;
  final bool disciplerAllowed;

  const _FellowshipMembersPage({
    required this.fellowshipId,
    required this.isMentor,
    this.fellowshipName,
    this.disciplerAllowed = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      // Back arrow only: the members screen draws its own heading (fellowship
      // name eyebrow, "Members", member count) like the settings pages.
      appBar: CommunityBackBar(background: palette.page),
      body: FellowshipMembersTabScreen(
        fellowshipId: fellowshipId,
        fellowshipName: fellowshipName,
        disciplerAllowed: disciplerAllowed,
        isAdmin: isViewerAdmin(context),
      ),
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
      useRootNavigator: true,
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
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      // Scheduling sits in the top bar ("+"), where the design puts it; the
      // label stays available as the tooltip / screen-reader name.
      appBar: CommunityBackBar(
        title: l10n.meetingsTitle,
        background: palette.page,
        actions: [
          if (isMentor)
            CommunityIconAction(
              icon: Icons.add_rounded,
              tooltip: l10n.meetingsSchedule,
              onPressed: () => _showScheduleSheet(context),
            ),
        ],
      ),
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
  final bool isMentor;
  final VoidCallback onViewAll;

  const _MeetingsSectionTile({
    required this.isMentor,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    return BlocBuilder<FellowshipMeetingsBloc, FellowshipMeetingsState>(
      builder: (context, state) {
        final next = state.meetings.isNotEmpty ? state.meetings.first : null;
        // An empty "Meetings" row tells a member nothing; a mentor keeps it
        // because it is where they schedule the first meeting.
        if (next == null && !isMentor) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: FellowshipCardShell(
            onTap: onViewAll,
            padding: const EdgeInsets.all(14),
            child: _meetingRow(context, next, l10n, palette, materialL10n),
          ),
        );
      },
    );
  }

  Widget _meetingRow(
    BuildContext context,
    FellowshipMeetingEntity? next,
    AppLocalizations l10n,
    ReaderPalette palette,
    MaterialLocalizations materialL10n,
  ) {
    final String title;
    final String? subtitle;
    if (next == null) {
      // Only a mentor gets here: the row invites them to schedule.
      title = l10n.meetingsTitle;
      subtitle = l10n.meetingsSchedulePrompt;
    } else {
      title = l10n.meetingsNextNoTime(next.title);
      final dt = DateTime.tryParse(next.startsAt)?.toLocal();
      subtitle = dt == null
          ? null
          : '${materialL10n.formatMediumDate(dt)} · '
              '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(dt))}';
    }
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.gold.withValues(alpha: palette.isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.videocam_outlined,
            color: palette.accentIcon,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 18, color: palette.dim),
      ],
    );
  }
}

/// Shown when a shared link leads to a fellowship the viewer is not in.
///
/// Joining is attempted through the public-join endpoint, which refuses any
/// fellowship that is not public — so a private group's link ends here with a
/// message rather than a way in.
class _NotAMemberCard extends StatefulWidget {
  final String fellowshipId;

  const _NotAMemberCard({required this.fellowshipId});

  @override
  State<_NotAMemberCard> createState() => _NotAMemberCardState();
}

class _NotAMemberCardState extends State<_NotAMemberCard> {
  bool _joining = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    final result = await sl<CommunityRepository>()
        .joinPublicFellowship(widget.fellowshipId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _joining = false;
        _error = ErrorMessageSanitizer.sanitize(failure);
      }),
      (_) {
        setState(() => _joining = false);
        // Reload the feed now that membership exists.
        context.read<FellowshipFeedBloc>().add(
            FellowshipFeedLoadRequested(fellowshipId: widget.fellowshipId));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FellowshipCardShell(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Icon(Icons.group_add_rounded, size: 40, color: palette.accentIcon),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.fellowshipJoinToViewTitle),
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(TranslationKeys.fellowshipJoinToViewBody),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 13,
                  color: palette.isDark
                      ? AppColors.errorLighter
                      : AppColors.errorDark,
                ),
              ),
            ],
            const SizedBox(height: 16),
            CommunityCtaPill(
              tall: true,
              label: context.tr(TranslationKeys.fellowshipJoinAction),
              loading: _joining,
              onPressed: _join,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutes or unmutes this fellowship's notifications for the current user.
///
/// Per group, and only for them: a member in several groups can quieten a busy
/// one without switching a whole category off everywhere.
Future<void> _toggleMuteNotifications(
  BuildContext context,
  String fellowshipId,
  bool muted,
) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await sl<CommunityRepository>().updateFellowship(
    fellowshipId: fellowshipId,
    notificationsMuted: muted,
  );
  if (!context.mounted) return;
  result.fold(
    (failure) => showAppSnackBar(
      context,
      ErrorMessageSanitizer.sanitize(failure),
      tone: AppSnackTone.error,
    ),
    (_) => showAppSnackBar(
      context,
      muted
          ? l10n.fellowshipNotificationsMuted
          : l10n.fellowshipNotificationsUnmuted,
    ),
  );
}
