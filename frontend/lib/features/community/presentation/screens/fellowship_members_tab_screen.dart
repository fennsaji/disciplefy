import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_invites_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/block_user_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_confirm_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Displays the member list for a fellowship and provides an invite action.
///
/// [FellowshipMembersBloc] is provided by the parent [FellowshipHomeScreen] —
/// this widget must NOT create its own BlocProvider.
class FellowshipMembersTabScreen extends StatelessWidget {
  /// The ID of the fellowship whose members are displayed.
  final String fellowshipId;
  final String? fellowshipName;

  /// Whether the Discipler AI helper is enabled for this fellowship — shows
  /// the Helpers section when true.
  final bool disciplerAllowed;

  /// Whether the current viewer is a global admin — admins may promote and
  /// demote members the same as a mentor.
  final bool isAdmin;

  const FellowshipMembersTabScreen({
    required this.fellowshipId,
    this.fellowshipName,
    this.disciplerAllowed = false,
    this.isAdmin = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      floatingActionButton:
          BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        buildWhen: (prev, curr) => prev.isMentor != curr.isMentor,
        builder: (context, state) {
          if (!state.isMentor) return const SizedBox.shrink();
          return CommunityCtaPill(
            large: true,
            icon: Icons.person_add_outlined,
            label: l10n.membersInvite,
            onPressed: () => _openInviteManagement(context, fellowshipName),
          );
        },
      ),
      body: BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        builder: (context, state) {
          final loaded = state.status == FellowshipMembersStatus.success;
          final heading = _MembersHeading(
            fellowshipName: fellowshipName,
            memberCount: loaded ? state.members.length : null,
          );
          switch (state.status) {
            case FellowshipMembersStatus.initial:
            case FellowshipMembersStatus.loading:
              return _StateLayout(
                heading: heading,
                child: Center(
                  child: CircularProgressIndicator(color: palette.accentIcon),
                ),
              );

            case FellowshipMembersStatus.failure:
              return _StateLayout(
                heading: heading,
                child: _ErrorView(
                  message: state.errorMessage ?? l10n.membersLoadError,
                  fellowshipId: fellowshipId,
                ),
              );

            case FellowshipMembersStatus.success:
              if (state.members.isEmpty) {
                return _StateLayout(
                  heading: heading,
                  child: const _EmptyView(),
                );
              }
              return BlocBuilder<LearningPathsBloc, LearningPathsState>(
                builder: (ctx, pathsState) {
                  int? totalTopics;
                  if (pathsState is LearningPathDetailLoaded) {
                    final count = pathsState.pathDetail.topics.length;
                    if (count > 0) totalTopics = count;
                  }
                  return _MemberList(
                    heading: heading,
                    members: state.members,
                    isMentor: state.isMentor,
                    isAdmin: isAdmin,
                    currentUserId: state.currentUserId,
                    fellowshipId: fellowshipId,
                    totalTopics: totalTopics,
                    disciplerAllowed: disciplerAllowed,
                  );
                },
              );
          }
        },
      ),
    );
  }

  void _openInviteManagement(BuildContext context, String? fellowshipName) {
    final bloc = context.read<FellowshipMembersBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: FellowshipInvitesScreen(
            fellowshipId: fellowshipId,
            fellowshipName: fellowshipName,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page heading and state layout
// ---------------------------------------------------------------------------

/// Gold tracked fellowship-name eyebrow, the Poppins "Members" title and the
/// member count ("5 members") once the roster has loaded.
class _MembersHeading extends StatelessWidget {
  final String? fellowshipName;

  /// Null while loading or after a failure: the count is unknown then.
  final int? memberCount;

  const _MembersHeading({this.fellowshipName, this.memberCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = memberCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: CommunityPageHeading(
        eyebrow: fellowshipName?.trim(),
        title: l10n.fellowshipTabMembers,
        subtitle: count == null
            ? null
            : '$count ${l10n.communityMembersCount(count)}',
      ),
    );
  }
}

/// The heading above a loading / empty / error view that fills the rest of
/// the screen and scrolls when the text runs taller than the viewport.
class _StateLayout extends StatelessWidget {
  final Widget heading;
  final Widget child;

  const _StateLayout({required this.heading, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: heading),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Member list
// ---------------------------------------------------------------------------

class _MemberList extends StatelessWidget {
  final Widget heading;
  final List<FellowshipMemberEntity> members;
  final bool isMentor;
  final bool isAdmin;
  final String? currentUserId;
  final String fellowshipId;
  final int? totalTopics;
  final bool disciplerAllowed;

  const _MemberList({
    required this.heading,
    required this.members,
    required this.isMentor,
    required this.currentUserId,
    required this.fellowshipId,
    this.isAdmin = false,
    this.totalTopics,
    this.disciplerAllowed = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final mentors = members.where((m) => m.role == 'mentor').toList()
      ..sort((a, b) => (a.isOwner == b.isOwner) ? 0 : (a.isOwner ? -1 : 1));
    final regularMembers = members.where((m) => m.role != 'mentor').toList();

    _MemberCard memberCard(FellowshipMemberEntity m) => _MemberCard(
          member: m,
          isMentor: isMentor,
          isAdmin: isAdmin,
          currentUserId: currentUserId,
          fellowshipId: fellowshipId,
          totalTopics: totalTopics,
        );

    // The page floats under the tab dock: the bottom inset already includes
    // the dock and the safe area. A mentor also has the invite pill floating
    // above it, so the last row needs room to scroll clear of that too.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset + (isMentor ? 96 : 24);

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      children: [
        heading,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mentors.isNotEmpty) ...[
                _SectionHeader(
                    title: l10n.mentorsSection, count: mentors.length),
                SettingsGroup(
                    children: [for (final m in mentors) memberCard(m)]),
              ],
              if (disciplerAllowed) ...[
                _SectionHeader(title: l10n.helpersSection, count: 1),
                const SettingsGroup(children: [_DisciplerHelperRow()]),
              ],
              if (regularMembers.isNotEmpty) ...[
                // Members get their own heading: without it they read as a
                // continuation of the Helpers list, which is Discipler only.
                _SectionHeader(
                    title: l10n.membersSection, count: regularMembers.length),
                SettingsGroup(
                    children: [for (final m in regularMembers) memberCard(m)]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

/// Gold tracked group label with its size: "MEMBERS · 4".
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: CommunitySectionLabel('$title · $count'),
    );
  }
}

// ---------------------------------------------------------------------------
// Discipler AI helper row (no menu — the helper cannot be muted/removed)
// ---------------------------------------------------------------------------

class _DisciplerHelperRow extends StatelessWidget {
  const _DisciplerHelperRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          const DisciplerAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.disciplerName,
                      style: AppFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const DisciplerAiChip(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.disciplerHelperSubtitle,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
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
}

// ---------------------------------------------------------------------------
// Member card
// ---------------------------------------------------------------------------

class _MemberCard extends StatelessWidget {
  final FellowshipMemberEntity member;

  /// True when the current viewer is the mentor of this fellowship.
  final bool isMentor;

  /// True when the current viewer is a global admin — treated the same as
  /// a mentor for promote/demote actions.
  final bool isAdmin;
  final String? currentUserId;
  final String fellowshipId;
  final int? totalTopics;

  const _MemberCard({
    required this.member,
    required this.isMentor,
    required this.currentUserId,
    required this.fellowshipId,
    this.isAdmin = false,
    this.totalTopics,
  });

  // ── Dialogs ─────────────────────────────────────────────────────────────

  Future<void> _showRemoveConfirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<FellowshipMembersBloc>();
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      title: l10n.removeMemberTitle,
      body: l10n.removeMemberConfirm,
      confirmLabel: l10n.removeMemberAction,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed) {
      bloc.add(FellowshipMembersRemoveRequested(userId: member.userId));
    }
  }

  Future<void> _showTransferConfirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<FellowshipMembersBloc>();
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: Icons.swap_horiz_rounded,
      title: l10n.transferMentorTitle,
      body: l10n.transferMentorConfirm,
      confirmLabel: l10n.transferMentorTitle,
      cancelLabel: l10n.cancel,
    );
    if (confirmed) {
      bloc.add(
          FellowshipTransferMentorRequested(newMentorUserId: member.userId));
    }
  }

  Future<void> _handleBlock(BuildContext context) async {
    // FellowshipFeedBloc is not reachable from this screen's widget tree
    // (the members tab route only provides FellowshipMembersBloc and
    // LearningPathsBloc — see fellowship_home_screen.dart `_openMembers`),
    // so block directly through the repository and refresh the member list.
    final membersBloc = context.read<FellowshipMembersBloc>();
    final successText = AppLocalizations.of(context)!.blockUserSuccess;
    final blockedUserId = member.userId;
    if (await showBlockUserConfirmation(context)) {
      final result = await sl<CommunityRepository>().blockUser(
        blockedUserId: blockedUserId,
      );
      result.fold(
        (failure) {
          if (!context.mounted) return;
          showAppSnackBar(context, ErrorMessageSanitizer.sanitize(failure),
              tone: AppSnackTone.error);
        },
        (_) {
          if (context.mounted) {
            showAppSnackBar(context, successText, tone: AppSnackTone.success);
          }
          membersBloc.add(
            FellowshipMembersLoadRequested(fellowshipId: fellowshipId),
          );
        },
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final errorColor =
        palette.isDark ? AppColors.errorLighter : AppColors.errorDark;
    final isMemberMentor = member.role == 'mentor';
    final joinDate = _formatJoinDate(member.joinedAt);

    // Mentors run their own group; a global admin may only change who mentors
    // it. The two were merged into one `viewerCanManage`, which offered an
    // admin — and so an ordinary member of a group they happen to administer —
    // mute, transfer and remove. Those are refused server-side with 403 (see
    // is_fellowship_mentor in fellowship-members), so the menu was showing
    // actions that could only fail. The split below matches what the backend
    // actually accepts: mentor-only for member management, mentor-or-admin for
    // the mentor role itself.
    final canManageMembers = isMentor;
    final canChangeMentorRole = isMentor || isAdmin;

    // Mentor may act on any non-mentor member (not on themselves/mentor card)
    final canAct = canManageMembers && !isMemberMentor;
    // Any viewer may block any other member, mentor or not.
    final canBlock = currentUserId != null && member.userId != currentUserId;
    // Promote a regular member to mentor.
    final canPromote = canChangeMentorRole && !isMemberMentor;
    // Demote a non-owner mentor back to member.
    final canDemote = canChangeMentorRole && isMemberMentor && !member.isOwner;
    final showMenu = canAct || canBlock || canPromote || canDemote;

    final isSelf = currentUserId != null && member.userId == currentUserId;
    final nameText = isSelf
        ? context.tr(TranslationKeys.communitySharedMentorYou,
            {'name': member.displayName})
        : member.displayName;

    return Padding(
      // The menu button brings its own touch padding on the trailing side.
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          // Profile photo (decoded at display size), else initials on a
          // colour derived from the name so a member keeps one tint.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: MemberAvatar(
              displayName: member.displayName,
              avatarUrl: member.avatarUrl,
            ),
          ),
          const SizedBox(width: 12),

          // ── Info column ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameText,
                    style: AppFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Role pill (mentors only — the section already says the
                  // rest are members), muted chip and join date. Wraps under
                  // itself when the labels run long.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isMemberMentor) _RoleBadge(isOwner: member.isOwner),
                      if (member.isMuted) const _MutedChip(),
                      if (joinDate.isNotEmpty)
                        Text(
                          '${l10n.memberJoinedLabel} $joinDate',
                          style: AppFonts.inter(
                            fontSize: 12.5,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),

                  // Progress bar — only shown to the mentor for all members
                  if (isMentor &&
                      totalTopics != null &&
                      member.topicsCompleted != null) ...[
                    const SizedBox(height: 10),
                    _MemberProgressBar(
                      completed: member.topicsCompleted!,
                      total: totalTopics!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Mentor action menu ───────────────────────────────────────────
          // Always reserve the same right-side width so the progress bar
          // and fraction text align consistently across all member cards.
          if (showMenu)
            PopupMenuButton<_MemberAction>(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              iconSize: 20,
              color: palette.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.hairline),
              ),
              icon: Icon(Icons.more_vert, color: palette.muted),
              onSelected: (action) {
                switch (action) {
                  case _MemberAction.mute:
                    context.read<FellowshipMembersBloc>().add(
                          FellowshipMembersMuteRequested(userId: member.userId),
                        );
                  case _MemberAction.unmute:
                    context.read<FellowshipMembersBloc>().add(
                          FellowshipMembersUnmuteRequested(
                              userId: member.userId),
                        );
                  case _MemberAction.transfer:
                    _showTransferConfirm(context);
                  case _MemberAction.remove:
                    _showRemoveConfirm(context);
                  case _MemberAction.block:
                    _handleBlock(context);
                  case _MemberAction.promote:
                    context.read<FellowshipMembersBloc>().add(
                          FellowshipMemberPromoteRequested(
                              userId: member.userId),
                        );
                  case _MemberAction.demote:
                    context.read<FellowshipMembersBloc>().add(
                          FellowshipMemberDemoteRequested(
                              userId: member.userId),
                        );
                }
              },
              itemBuilder: (_) => [
                if (canAct) ...[
                  // Mute / unmute
                  PopupMenuItem(
                    value: member.isMuted
                        ? _MemberAction.unmute
                        : _MemberAction.mute,
                    child: _PopupItem(
                      icon: member.isMuted
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      label: member.isMuted
                          ? l10n.unmuteMemberAction
                          : l10n.muteMemberAction,
                      color: palette.text,
                    ),
                  ),
                  // Transfer mentor role
                  PopupMenuItem(
                    value: _MemberAction.transfer,
                    child: _PopupItem(
                      icon: Icons.swap_horiz_rounded,
                      label: l10n.transferMentorTitle,
                      color: palette.text,
                    ),
                  ),
                ],
                if (canPromote)
                  PopupMenuItem(
                    value: _MemberAction.promote,
                    child: _PopupItem(
                      icon: Icons.arrow_upward_rounded,
                      label: l10n.promoteToMentor,
                      color: palette.text,
                    ),
                  ),
                if (canDemote)
                  PopupMenuItem(
                    value: _MemberAction.demote,
                    child: _PopupItem(
                      icon: Icons.arrow_downward_rounded,
                      label: l10n.demoteToMember,
                      color: palette.text,
                    ),
                  ),
                if (canAct)
                  // Remove — destructive, shown in error red
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: _PopupItem(
                      icon: Icons.person_remove_outlined,
                      label: l10n.removeMemberTitle,
                      color: errorColor,
                    ),
                  ),
                if (canBlock)
                  PopupMenuItem(
                    value: _MemberAction.block,
                    child: _PopupItem(
                      icon: Icons.block,
                      label: l10n.blockUserTitle,
                      color: errorColor,
                    ),
                  ),
              ],
            )
          else
            // Placeholder so the Expanded info column is the same width on
            // every card (e.g. the viewer's own card has no ⋮ button).
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Popup menu helpers ──────────────────────────────────────────────────────

enum _MemberAction { mute, unmute, transfer, remove, block, promote, demote }

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PopupItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        // Expanded, because these labels are longer in Hindi and Malayalam than
        // the menu is wide — "Block user" overflowed its row by 24px in
        // Malayalam. Two lines rather than a clipped one: a menu entry that
        // cannot be read in full is worse than a slightly taller menu.
        Expanded(
          child: Text(
            label,
            style: AppFonts.inter(fontSize: 15, color: color),
          ),
        ),
      ],
    );
  }
}

// ── Muted chip ──────────────────────────────────────────────────────────────

class _MutedChip extends StatelessWidget {
  const _MutedChip();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_outlined, size: 12, color: palette.muted),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.membersMuted,
            style: AppFonts.inter(fontSize: 12, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

/// Gold "Owner" / "Mentor" pill. Regular members get none: their section
/// heading already says what they are, so a "Member" chip on every row was
/// noise.
class _RoleBadge extends StatelessWidget {
  final bool isOwner;

  const _RoleBadge({this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: palette.isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOwner ? l10n.ownerLabel : l10n.mentorLabel,
        style: AppFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: palette.gold,
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member progress bar (mentor view)
// ---------------------------------------------------------------------------

class _MemberProgressBar extends StatelessWidget {
  final int completed;
  final int total;

  const _MemberProgressBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final progress =
        total > 0 ? (completed / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Row(
      children: [
        Expanded(child: CommunityProgressBar(value: progress)),
        const SizedBox(width: 8),
        Text(
          '$completed/$total',
          style: AppFonts.inter(fontSize: 12, color: palette.muted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 56, color: palette.dim),
            const SizedBox(height: 16),
            Text(
              l10n.membersEmpty,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.membersEmptyDescription,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final String fellowshipId;

  const _ErrorView({required this.message, required this.fellowshipId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: palette.dim),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 15,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            CommunityCtaPill(
              icon: Icons.refresh,
              label: l10n.membersRetry,
              onPressed: () => context.read<FellowshipMembersBloc>().add(
                    FellowshipMembersLoadRequested(
                      fellowshipId: fellowshipId,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Formats an ISO-8601 join date string as "MMM yyyy" (e.g. "Mar 2025").
String _formatJoinDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '';
  }
}
