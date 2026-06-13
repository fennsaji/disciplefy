import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/fellowship_members/fellowship_members_bloc.dart';
import '../bloc/fellowship_members/fellowship_members_event.dart';
import '../bloc/fellowship_members/fellowship_members_state.dart';

/// Full-screen invite-link management for fellowship mentors.
///
/// Lists every active invite link with its usage count and expiry, and lets
/// the mentor generate new reusable links, copy/share them, or revoke them.
///
/// Reuses the [FellowshipMembersBloc] provided by [FellowshipHomeScreen] —
/// push this screen with a `BlocProvider.value` wrapping that BLoC.
class FellowshipInvitesScreen extends StatefulWidget {
  /// The ID of the fellowship whose invite links are managed.
  final String fellowshipId;

  /// Display name of the fellowship, used in the share message.
  final String? fellowshipName;

  const FellowshipInvitesScreen({
    required this.fellowshipId,
    this.fellowshipName,
    super.key,
  });

  @override
  State<FellowshipInvitesScreen> createState() =>
      _FellowshipInvitesScreenState();
}

class _FellowshipInvitesScreenState extends State<FellowshipInvitesScreen> {
  @override
  void initState() {
    super.initState();
    // Load the active invite links when the screen opens.
    context
        .read<FellowshipMembersBloc>()
        .add(const FellowshipInvitesListRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appScaffold,
      appBar: AppBar(
        backgroundColor: context.appScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.inviteManageTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
        buildWhen: (prev, curr) =>
            prev.invitesList != curr.invitesList ||
            prev.invitesListStatus != curr.invitesListStatus ||
            prev.inviteStatus != curr.inviteStatus,
        builder: (context, state) {
          final isLoading =
              state.invitesListStatus == FellowshipInvitesListStatus.loading &&
                  state.invitesList.isEmpty;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  l10n.inviteManageSubtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.invitesList.isEmpty
                        ? _EmptyLinks(l10n: l10n)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: state.invitesList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _InviteCard(
                              invite: state.invitesList[i],
                              fellowshipName: widget.fellowshipName,
                            ),
                          ),
              ),
              _GenerateBar(
                generating:
                    state.inviteStatus == FellowshipInviteStatus.loading,
                error: state.inviteStatus == FellowshipInviteStatus.failure
                    ? state.inviteError
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite card — one active link
// ---------------------------------------------------------------------------

class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> invite;
  final String? fellowshipName;

  const _InviteCard({required this.invite, this.fellowshipName});

  String get _token => invite['token'] as String? ?? '';

  String get _joinUrl =>
      (invite['join_url'] as String?) ??
      'https://app.disciplefy.in/fellowship/join/$_token';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    final useCount = (invite['use_count'] as num?)?.toInt() ?? 0;
    final maxUses = (invite['max_uses'] as num?)?.toInt();

    final usageLabel = maxUses == null
        ? '$useCount ${l10n.inviteJoinedSuffix} · ${l10n.inviteUnlimited}'
        : '$useCount / $maxUses';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Code + copy-code ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  _token.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CopyIconButton(
                text: _token,
                tooltip: l10n.inviteCopyCode,
                copiedMessage: l10n.inviteCodeCopied,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Full link (visible for reference; shared via Invite) ────────
          Text(
            _joinUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appTextTertiary,
            ),
          ),
          const SizedBox(height: 10),
          // ── Usage + expiry ─────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.group_outlined, size: 14, color: primary),
              const SizedBox(width: 4),
              Text(
                usageLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule_rounded,
                  size: 13, color: context.appTextTertiary),
              const SizedBox(width: 4),
              Text(
                l10n.inviteExpires,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          // ── Actions ────────────────────────────────────────────────────
          Row(
            children: [
              _TextAction(
                icon: Icons.share_outlined,
                label: l10n.membersInvite,
                color: primary,
                onTap: () {
                  final name = fellowshipName?.isNotEmpty == true
                      ? fellowshipName!
                      : 'my fellowship';
                  Share.share('Join $name on Disciplefy:\n$_joinUrl');
                },
              ),
              const Spacer(),
              _TextAction(
                icon: Icons.link_off_rounded,
                label: l10n.inviteRevoke,
                color: AppColors.error,
                onTap: () {
                  final inviteId = invite['id'] as String? ?? '';
                  context.read<FellowshipMembersBloc>().add(
                        FellowshipInviteRevokeRequested(inviteId: inviteId),
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate-link bar (bottom)
// ---------------------------------------------------------------------------

class _GenerateBar extends StatelessWidget {
  final bool generating;
  final String? error;

  const _GenerateBar({required this.generating, this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: generating
                    ? null
                    : () => context.read<FellowshipMembersBloc>().add(
                          const FellowshipMembersInviteRequested(),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appInteractive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_link_rounded),
                label: Text(
                  l10n.inviteGenerateLink,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
// Empty state
// ---------------------------------------------------------------------------

class _EmptyLinks extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyLinks({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_rounded, size: 56, color: context.appTextTertiary),
            const SizedBox(height: 16),
            Text(
              l10n.inviteNoLinks,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.inviteNoLinksDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small action helpers
// ---------------------------------------------------------------------------

class _TextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CopyIconButton extends StatefulWidget {
  final String text;
  final String tooltip;
  final String copiedMessage;

  const _CopyIconButton({
    required this.text,
    required this.tooltip,
    required this.copiedMessage,
  });

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(widget.copiedMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _copy,
      tooltip: widget.tooltip,
      icon: Icon(
        _copied ? Icons.check_circle_outline : Icons.copy_outlined,
        color:
            _copied ? AppColors.success : Theme.of(context).colorScheme.primary,
        size: 22,
      ),
    );
  }
}
