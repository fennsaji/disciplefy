import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/community/domain/entities/fellowship_member_entity.dart';
import '../../../../features/community/domain/repositories/community_repository.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_state.dart';
import '../bloc/fellowship_members/fellowship_members_bloc.dart';
import '../bloc/fellowship_members/fellowship_members_event.dart';
import '../bloc/fellowship_members/fellowship_members_state.dart';
import '../widgets/block_user_dialog.dart';
import '../widgets/discipler_badges.dart';
import 'fellowship_invites_screen.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

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
    return Scaffold(
      backgroundColor: context.appScaffold,
      floatingActionButton:
          BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        buildWhen: (prev, curr) => prev.isMentor != curr.isMentor,
        builder: (context, state) {
          if (!state.isMentor) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _openInviteManagement(context, fellowshipName),
            backgroundColor: context.appInteractive,
            foregroundColor: AppColors.onGradient,
            icon: const Icon(Icons.person_add_outlined),
            label: Text(
              l10n.membersInvite,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
      body: BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        builder: (context, state) {
          switch (state.status) {
            case FellowshipMembersStatus.initial:
            case FellowshipMembersStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case FellowshipMembersStatus.failure:
              return _ErrorView(
                message: state.errorMessage ?? l10n.membersLoadError,
                fellowshipId: fellowshipId,
              );

            case FellowshipMembersStatus.success:
              if (state.members.isEmpty) {
                return const _EmptyView();
              }
              return BlocBuilder<LearningPathsBloc, LearningPathsState>(
                builder: (ctx, pathsState) {
                  int? totalTopics;
                  if (pathsState is LearningPathDetailLoaded) {
                    final count = pathsState.pathDetail.topics.length;
                    if (count > 0) totalTopics = count;
                  }
                  return _MemberList(
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
// Member list
// ---------------------------------------------------------------------------

class _MemberList extends StatelessWidget {
  final List<FellowshipMemberEntity> members;
  final bool isMentor;
  final bool isAdmin;
  final String? currentUserId;
  final String fellowshipId;
  final int? totalTopics;
  final bool disciplerAllowed;

  const _MemberList({
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

    final rows = <Widget>[
      if (mentors.isNotEmpty) _SectionHeader(title: l10n.mentorsSection),
      for (final m in mentors)
        _MemberCard(
          member: m,
          isMentor: isMentor,
          isAdmin: isAdmin,
          currentUserId: currentUserId,
          fellowshipId: fellowshipId,
          totalTopics: totalTopics,
        ),
      if (disciplerAllowed) ...[
        _SectionHeader(title: l10n.helpersSection),
        const _DisciplerHelperRow(),
      ],
      if (regularMembers.isNotEmpty) ...[
        // Members get their own heading: without it they read as a continuation
        // of the Helpers list, which is Discipler only.
        _SectionHeader(title: l10n.membersSection),
        for (final m in regularMembers)
          _MemberCard(
            member: m,
            isMentor: isMentor,
            isAdmin: isAdmin,
            currentUserId: currentUserId,
            fellowshipId: fellowshipId,
            totalTopics: totalTopics,
          ),
      ],
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: context.appDivider,
      ),
      itemBuilder: (context, index) => rows[index],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.appTextTertiary,
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const DisciplerAvatar(radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.disciplerName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const DisciplerAiChip(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.disciplerHelperSubtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: context.appTextTertiary,
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

  void _showRemoveConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.removeMemberTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          l10n.removeMemberConfirm,
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
              context.read<FellowshipMembersBloc>().add(
                    FellowshipMembersRemoveRequested(userId: member.userId),
                  );
            },
            child: Text(
              l10n.removeMemberAction,
              style: TextStyle(color: context.appError),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.transferMentorTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          l10n.transferMentorConfirm,
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
              context.read<FellowshipMembersBloc>().add(
                    FellowshipTransferMentorRequested(
                        newMentorUserId: member.userId),
                  );
            },
            child: Text(
              l10n.transferMentorTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBlock(BuildContext context) async {
    // FellowshipFeedBloc is not reachable from this screen's widget tree
    // (the members tab route only provides FellowshipMembersBloc and
    // LearningPathsBloc — see fellowship_home_screen.dart `_openMembers`),
    // so block directly through the repository and refresh the member list.
    final membersBloc = context.read<FellowshipMembersBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final successText = AppLocalizations.of(context)!.blockUserSuccess;
    final blockedUserId = member.userId;
    if (await showBlockUserConfirmation(context)) {
      final result = await sl<CommunityRepository>().blockUser(
        blockedUserId: blockedUserId,
      );
      result.fold(
        (failure) {
          messenger.showSnackBar(
              SnackBar(content: Text(ErrorMessageSanitizer.sanitize(failure))));
        },
        (_) {
          messenger.showSnackBar(SnackBar(content: Text(successText)));
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
    final isMemberMentor = member.role == 'mentor';
    final initials = _initials(member.displayName);
    final joinDate = _formatJoinDate(member.joinedAt);

    final viewerCanManage = isMentor || isAdmin;
    // Mentor/admin may act on any non-mentor member (not on themselves/mentor card)
    final canAct = viewerCanManage && !isMemberMentor;
    // Any viewer may block any other member, mentor or not.
    final canBlock = currentUserId != null && member.userId != currentUserId;
    // Promote a regular member to mentor.
    final canPromote = viewerCanManage && !isMemberMentor;
    // Demote a non-owner mentor back to member.
    final canDemote = viewerCanManage && isMemberMentor && !member.isOwner;
    final showMenu = canAct || canBlock || canPromote || canDemote;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          _MemberAvatar(
            avatarUrl: member.avatarUrl,
            initials: initials,
          ),
          const SizedBox(width: 12),

          // ── Info column ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + muted chip on same row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.isMuted) ...[
                      const SizedBox(width: 6),
                      _MutedChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Role badge + join date
                Row(
                  children: [
                    _RoleBadge(
                        isMentor: isMemberMentor, isOwner: member.isOwner),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: context.appTextTertiary),
                    const SizedBox(width: 3),
                    Text(
                      '${l10n.memberJoinedLabel} $joinDate',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),

                // Progress bar — only shown to the mentor for all members
                if (isMentor &&
                    totalTopics != null &&
                    member.topicsCompleted != null) ...[
                  const SizedBox(height: 8),
                  _MemberProgressBar(
                    completed: member.topicsCompleted!,
                    total: totalTopics!,
                  ),
                ],
              ],
            ),
          ),

          // ── Mentor action menu ───────────────────────────────────────────
          // Always reserve the same right-side width so the progress bar
          // and fraction text align consistently across all member cards.
          if (showMenu)
            PopupMenuButton<_MemberAction>(
              iconSize: 20,
              icon: Icon(Icons.more_vert, color: context.appTextTertiary),
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
                          ? l10n.unmuteSuccess
                          : l10n.muteSuccess,
                      color: context.appTextPrimary,
                    ),
                  ),
                  // Transfer mentor role
                  PopupMenuItem(
                    value: _MemberAction.transfer,
                    child: _PopupItem(
                      icon: Icons.swap_horiz_rounded,
                      label: l10n.transferMentorTitle,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
                if (canPromote)
                  PopupMenuItem(
                    value: _MemberAction.promote,
                    child: _PopupItem(
                      icon: Icons.arrow_upward_rounded,
                      label: l10n.promoteToMentor,
                      color: context.appTextPrimary,
                    ),
                  ),
                if (canDemote)
                  PopupMenuItem(
                    value: _MemberAction.demote,
                    child: _PopupItem(
                      icon: Icons.arrow_downward_rounded,
                      label: l10n.demoteToMember,
                      color: context.appTextPrimary,
                    ),
                  ),
                if (canAct)
                  // Remove — destructive, shown in error red
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: _PopupItem(
                      icon: Icons.person_remove_outlined,
                      label: l10n.removeMemberTitle,
                      color: AppColors.error,
                    ),
                  ),
                if (canBlock)
                  PopupMenuItem(
                    value: _MemberAction.block,
                    child: _PopupItem(
                      icon: Icons.block,
                      label: l10n.blockUserTitle,
                      color: AppColors.error,
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
        Text(label,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: color)),
      ],
    );
  }
}

// ── Muted chip ──────────────────────────────────────────────────────────────

class _MutedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_outlined,
              size: 10, color: context.appTextTertiary),
          const SizedBox(width: 3),
          Text(
            AppLocalizations.of(context)!.membersMuted,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  final bool isMentor;
  final bool isOwner;

  const _RoleBadge({required this.isMentor, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = isOwner
        ? l10n.ownerLabel
        : (isMentor ? l10n.mentorLabel : l10n.memberLabel);
    final backgroundColor =
        isMentor ? AppColors.warningLight : context.appSurfaceVariant;
    final textColor =
        isMentor ? AppColors.warningDark : context.appTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
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
    final progress = (completed / total).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.appSurfaceVariant,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$completed/$total',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appTextTertiary,
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: context.appTextTertiary),
          const SizedBox(height: 16),
          Text(
            l10n.membersEmpty,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.membersEmptyDescription,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.appTextTertiary),
          ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.appError,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.read<FellowshipMembersBloc>().add(
                    FellowshipMembersLoadRequested(
                      fellowshipId: fellowshipId,
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appInteractive,
                foregroundColor: AppColors.onGradient,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                l10n.membersRetry,
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

/// Returns up to 2 uppercase initials from a display name.
/// "Fenn Saji" → "FS", "John" → "J", "" → "?"
String _initials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Circular avatar that shows a network image when available, falling back
/// to coloured initials if the URL is null or the image fails to load.
class _MemberAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;

  const _MemberAvatar({required this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = context.appSurfaceVariant;

    final initialsWidget = CircleAvatar(
      radius: 24,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: primary,
        ),
      ),
    );

    if (avatarUrl == null) return initialsWidget;

    return ClipOval(
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => initialsWidget,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return initialsWidget;
          },
        ),
      ),
    );
  }
}
