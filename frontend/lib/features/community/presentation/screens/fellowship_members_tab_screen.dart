import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/community/domain/entities/fellowship_member_entity.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_state.dart';
import '../bloc/fellowship_members/fellowship_members_bloc.dart';
import '../bloc/fellowship_members/fellowship_members_event.dart';
import '../bloc/fellowship_members/fellowship_members_state.dart';

/// Displays the member list for a fellowship and provides an invite action.
///
/// [FellowshipMembersBloc] is provided by the parent [FellowshipHomeScreen] —
/// this widget must NOT create its own BlocProvider.
class FellowshipMembersTabScreen extends StatelessWidget {
  /// The ID of the fellowship whose members are displayed.
  final String fellowshipId;
  final String? fellowshipName;

  const FellowshipMembersTabScreen({
    required this.fellowshipId,
    this.fellowshipName,
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
            onPressed: () => _showInviteSheet(context, fellowshipName),
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
                    totalTopics: totalTopics,
                  );
                },
              );
          }
        },
      ),
    );
  }

  void _showInviteSheet(BuildContext context, String? fellowshipName) {
    final bloc = context.read<FellowshipMembersBloc>();
    // Load the active invites list when opening the sheet.
    bloc.add(const FellowshipInvitesListRequested());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _InviteSheet(fellowshipName: fellowshipName),
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
  final int? totalTopics;

  const _MemberList({
    required this.members,
    required this.isMentor,
    this.totalTopics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: members.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: context.appDivider,
      ),
      itemBuilder: (context, index) => _MemberCard(
        member: members[index],
        isMentor: isMentor,
        totalTopics: totalTopics,
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
  final int? totalTopics;

  const _MemberCard({
    required this.member,
    required this.isMentor,
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
              style: const TextStyle(color: AppColors.error),
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMemberMentor = member.role == 'mentor';
    final initials = _initials(member.displayName);
    final joinDate = _formatJoinDate(member.joinedAt);

    // Mentor may act on any non-mentor member (not on themselves/mentor card)
    final canAct = isMentor && !isMemberMentor;

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
                    _RoleBadge(isMentor: isMemberMentor),
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
          if (canAct)
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
                }
              },
              itemBuilder: (_) => [
                // Mute / unmute
                PopupMenuItem(
                  value: member.isMuted
                      ? _MemberAction.unmute
                      : _MemberAction.mute,
                  child: _PopupItem(
                    icon: member.isMuted
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    label:
                        member.isMuted ? l10n.unmuteSuccess : l10n.muteSuccess,
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
                // Remove — destructive, shown in error red
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: _PopupItem(
                    icon: Icons.person_remove_outlined,
                    label: l10n.removeMemberTitle,
                    color: AppColors.error,
                  ),
                ),
              ],
            )
          else if (isMentor)
            // Placeholder so the Expanded info column is the same width on
            // every card (mentor's own card has no ⋮ button).
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Popup menu helpers ──────────────────────────────────────────────────────

enum _MemberAction { mute, unmute, transfer, remove }

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

  const _RoleBadge({required this.isMentor});

  @override
  Widget build(BuildContext context) {
    final label = isMentor ? 'Mentor' : 'Member';
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
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

// ---------------------------------------------------------------------------
// Invite bottom sheet
// ---------------------------------------------------------------------------

class _InviteSheet extends StatelessWidget {
  final String? fellowshipName;
  const _InviteSheet({this.fellowshipName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
      buildWhen: (prev, curr) =>
          prev.inviteStatus != curr.inviteStatus ||
          prev.inviteToken != curr.inviteToken ||
          prev.invitesListStatus != curr.invitesListStatus ||
          prev.invitesList != curr.invitesList,
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                // Title
                Text(
                  l10n.membersInviteTitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.membersInviteSubtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── State-driven content ──────────────────────────────
                if (state.inviteStatus == FellowshipInviteStatus.loading ||
                    state.invitesListStatus ==
                        FellowshipInvitesListStatus.loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                // Freshly generated invite
                else if (state.inviteStatus == FellowshipInviteStatus.success &&
                    state.inviteToken != null)
                  _InviteTokenRow(
                    token: state.inviteToken!,
                    inviteId: state.inviteId,
                    expiresLabel: l10n.inviteExpires,
                    fellowshipName: fellowshipName,
                  )
                // Already has an active code — show it, hide the generate button
                else if (state.invitesList.isNotEmpty)
                  _InviteTokenRow(
                    token: state.invitesList.first['token'] as String? ?? '',
                    inviteId: state.invitesList.first['id'] as String?,
                    expiresLabel: l10n.inviteExpires,
                    fellowshipName: fellowshipName,
                  )
                else ...[
                  // No active codes → show generate button
                  if (state.inviteStatus == FellowshipInviteStatus.failure &&
                      state.inviteError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.inviteError!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.read<FellowshipMembersBloc>().add(
                                const FellowshipMembersInviteRequested(),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appInteractive,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.link_rounded),
                      label: Text(
                        l10n.membersInvite,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Active invite row — shows token + revoke button
// ---------------------------------------------------------------------------

class _ActiveInviteRow extends StatelessWidget {
  final Map<String, dynamic> invite;

  const _ActiveInviteRow({required this.invite});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final token = invite['token'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              token,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: context.appTextPrimary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CopyButton(text: token),
          TextButton(
            onPressed: () {
              final inviteId = invite['id'] as String? ?? '';
              context.read<FellowshipMembersBloc>().add(
                    FellowshipInviteRevokeRequested(inviteId: inviteId),
                  );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              l10n.inviteRevoke,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite token row (shows token + copy button + expiry note)
// ---------------------------------------------------------------------------

class _InviteTokenRow extends StatelessWidget {
  final String token;
  final String? inviteId;
  final String expiresLabel;
  final String? fellowshipName;

  const _InviteTokenRow({
    required this.token,
    required this.expiresLabel,
    this.inviteId,
    this.fellowshipName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final letters = token.toUpperCase().split('');
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Letter tiles
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(letters.length, (i) {
            return Container(
              margin: i < letters.length - 1
                  ? const EdgeInsets.only(right: 8)
                  : null,
              width: 46,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? primary.withOpacity(0.12)
                    : primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                letters[i],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  height: 1,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        // Copy + share + expiry + revoke row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CopyButton(text: token),
            const SizedBox(width: 8),
            _ShareLinkButton(token: token, fellowshipName: fellowshipName),
            const SizedBox(width: 16),
            Icon(Icons.schedule_rounded,
                size: 13, color: context.appTextTertiary),
            const SizedBox(width: 4),
            Text(
              expiresLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: context.appTextTertiary,
              ),
            ),
            if (inviteId != null) ...[
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => context.read<FellowshipMembersBloc>().add(
                      FellowshipInviteRevokeRequested(inviteId: inviteId!),
                    ),
                child: Text(
                  l10n.inviteRevoke,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Copy button
// ---------------------------------------------------------------------------

class _CopyButton extends StatefulWidget {
  final String text;

  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _copied
          ? const Icon(
              Icons.check_circle_outline,
              key: ValueKey('check'),
              color: AppColors.success,
              size: 28,
            )
          : IconButton(
              key: const ValueKey('copy'),
              onPressed: _copy,
              tooltip: AppLocalizations.of(context)!.membersCopy,
              icon: Icon(
                Icons.copy_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Share link button
// ---------------------------------------------------------------------------

class _ShareLinkButton extends StatelessWidget {
  final String token;
  final String? fellowshipName;

  const _ShareLinkButton({required this.token, this.fellowshipName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        final url = 'https://app.disciplefy.in/fellowship/join/$token';
        final name = fellowshipName?.isNotEmpty == true
            ? fellowshipName!
            : 'my fellowship';
        Share.share('Join $name on Disciplefy:\n$url');
      },
      tooltip: 'Share invite link',
      icon: Icon(
        Icons.share_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
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
