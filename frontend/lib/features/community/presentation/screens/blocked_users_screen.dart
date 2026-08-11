import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../bloc/blocked_users/blocked_users_bloc.dart';
import '../bloc/blocked_users/blocked_users_event.dart';
import '../bloc/blocked_users/blocked_users_state.dart';

/// Settings → Blocked Users: lists blocked members and lets the user
/// unblock them.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<BlockedUsersBloc>()..add(const BlockedUsersLoadRequested()),
      child: const _BlockedUsersView(),
    );
  }
}

class _BlockedUsersView extends StatelessWidget {
  const _BlockedUsersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: BlocBuilder<BlockedUsersBloc, BlockedUsersState>(
        builder: (context, state) {
          switch (state.status) {
            case BlockedUsersStatus.initial:
            case BlockedUsersStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case BlockedUsersStatus.failure:
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.errorMessage ?? ''),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context
                          .read<BlockedUsersBloc>()
                          .add(const BlockedUsersLoadRequested()),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              );
            case BlockedUsersStatus.success:
              if (state.users.isEmpty) {
                return Center(child: Text(l10n.blockedUsersEmpty));
              }
              return ListView.builder(
                itemCount: state.users.length,
                itemBuilder: (context, index) {
                  final user = state.users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                      child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    title: Text(user.displayName),
                    trailing: TextButton(
                      onPressed: () {
                        context
                            .read<BlockedUsersBloc>()
                            .add(BlockedUserUnblockRequested(user.userId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.unblockSuccess)),
                        );
                      },
                      child: Text(l10n.unblockAction),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
