import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/share_links.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: l10n.inviteManageTitle,
        background: palette.page,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.inviteManageSubtitle,
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: palette.muted,
                    height: 1.45,
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

  // The backend already returns the correct go.disciplefy.in URL
  // (fellowship-invites/index.ts); the fallback exists only for a payload
  // shaped by an older backend version and must use the same host — a
  // hardcoded app.disciplefy.in here sent people without the app to a bare
  // client-side page with no preview and no app-store fallback, instead of
  // the server-rendered landing page ShareLinks.fellowshipInvite already
  // builds for every other invite-sharing path in the app.
  String get _joinUrl =>
      (invite['join_url'] as String?) ?? ShareLinks.fellowshipInvite(_token);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final useCount = (invite['use_count'] as num?)?.toInt() ?? 0;
    final maxUses = (invite['max_uses'] as num?)?.toInt();

    final usageLabel = maxUses == null
        ? '$useCount ${l10n.inviteJoinedSuffix} · ${l10n.inviteUnlimited}'
        : '$useCount / $maxUses';
    final meta = AppFonts.inter(fontSize: 13, color: palette.muted);

    return CommunityFormCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Code + copy-code ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _token.toUpperCase(),
                    maxLines: 1,
                    style: AppFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: palette.text,
                    ),
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
          // ── Full link (visible for reference; shared via Invite) ────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _joinUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(fontSize: 12.5, color: palette.dim),
            ),
          ),
          const SizedBox(height: 10),
          // ── Usage + expiry ─────────────────────────────────────────────
          // Wrap, not Row: "unlimited join" and the expiry text are both
          // longer in Malayalam than in English, and together they overflowed
          // the card by 101px — the expiry text ran clean off the screen.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 6,
            children: [
              Icon(Icons.group_outlined, size: 15, color: palette.gold),
              Text(usageLabel,
                  style: meta.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 14, color: palette.dim),
              Text(l10n.inviteExpires, style: meta),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: palette.hairline),
          // ── Actions ────────────────────────────────────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              _TextAction(
                icon: Icons.ios_share_rounded,
                label: l10n.membersInvite,
                color: palette.accentIcon,
                onTap: () {
                  final name = fellowshipName?.isNotEmpty == true
                      ? fellowshipName!
                      : 'my fellowship';
                  Share.share('Join $name on Disciplefy:\n$_joinUrl');
                },
              ),
              _TextAction(
                icon: Icons.link_off_rounded,
                label: l10n.inviteRevoke,
                color:
                    SettingsToneColors.of(context, SettingsTone.red).foreground,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: SettingsToneColors.of(context, SettingsTone.red)
                        .foreground,
                  ),
                ),
              ),
            SettingsButton(
              label: l10n.inviteGenerateLink,
              icon: Icons.add_link_rounded,
              loading: generating,
              onPressed: generating
                  ? null
                  : () => context.read<FellowshipMembersBloc>().add(
                        const FellowshipMembersInviteRequested(),
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
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 48, color: palette.dim),
            const SizedBox(height: 14),
            Text(
              l10n.inviteNoLinks,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.inviteNoLinksDescription,
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
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
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
    showAppSnackBar(context, widget.copiedMessage, tone: AppSnackTone.success);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return IconButton(
      onPressed: _copy,
      tooltip: widget.tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(
        _copied ? Icons.check_circle_outline : Icons.copy_rounded,
        color: _copied
            ? SettingsToneColors.of(context, SettingsTone.green).foreground
            : palette.accentIcon,
        size: 21,
      ),
    );
  }
}
