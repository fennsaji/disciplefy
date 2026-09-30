import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/blocked_users/blocked_users_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';

/// Settings → Blocked Users: lists blocked members and lets the user
/// unblock them.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<BlockedUsersBloc>()..add(const BlockedUsersLoadRequested()),
      child: const BlockedUsersView(),
    );
  }
}

/// The list itself, reading the [BlockedUsersBloc] above it.
class BlockedUsersView extends StatelessWidget {
  const BlockedUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: SettingsTopBar(title: l10n.blockedUsersTitle),
      body: BlocBuilder<BlockedUsersBloc, BlockedUsersState>(
        builder: (context, state) {
          switch (state.status) {
            case BlockedUsersStatus.initial:
            case BlockedUsersStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case BlockedUsersStatus.failure:
              return _Message(
                icon: Icons.cloud_off_rounded,
                text: state.errorMessage ?? '',
                action: SettingsButton(
                  label: l10n.retryButton,
                  height: 44,
                  onPressed: () => context
                      .read<BlockedUsersBloc>()
                      .add(const BlockedUsersLoadRequested()),
                ),
              );
            case BlockedUsersStatus.success:
              if (state.users.isEmpty) {
                return _Message(
                  icon: Icons.person_off_outlined,
                  text: l10n.blockedUsersEmpty,
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  SettingsGroup(
                    children: [
                      for (final user in state.users)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                          child: Row(
                            children: [
                              MemberAvatar(
                                displayName: user.displayName,
                                avatarUrl: user.avatarUrl,
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.displayName,
                                  style: AppFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                    color: palette.text,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SettingsButton(
                                label: l10n.unblockAction,
                                kind: SettingsButtonKind.neutral,
                                height: 40,
                                onPressed: () {
                                  context.read<BlockedUsersBloc>().add(
                                      BlockedUserUnblockRequested(user.userId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(l10n.unblockSuccess)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
          }
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: palette.dim),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 15,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
