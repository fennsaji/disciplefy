import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/discipler_activity_entity.dart';
import '../bloc/discipler_activity/discipler_activity_bloc.dart';
import '../bloc/discipler_activity/discipler_activity_event.dart';
import '../bloc/discipler_activity/discipler_activity_state.dart';
import '../widgets/discipler_badges.dart';

/// Mentor-facing screen listing what the Discipler AI helper has done in a
/// fellowship: drafted/answered replies, reactions, and daily study posts.
///
/// Reads the [DisciplerActivityBloc] provided by the route.
class DisciplerActivityScreen extends StatefulWidget {
  final String fellowshipId;

  const DisciplerActivityScreen({required this.fellowshipId, super.key});

  @override
  State<DisciplerActivityScreen> createState() =>
      _DisciplerActivityScreenState();
}

class _DisciplerActivityScreenState extends State<DisciplerActivityScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedKind;

  @override
  void initState() {
    super.initState();
    context.read<DisciplerActivityBloc>().add(
          DisciplerActivityLoadRequested(fellowshipId: widget.fellowshipId),
        );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.maxScrollExtent - _scrollController.offset <=
        200) {
      final state = context.read<DisciplerActivityBloc>().state;
      if (state.hasMore && state.status != DisciplerActivityStatus.loading) {
        context
            .read<DisciplerActivityBloc>()
            .add(const DisciplerActivityLoadMoreRequested());
      }
    }
  }

  void _selectKind(String? kind) {
    setState(() => _selectedKind = kind);
    context.read<DisciplerActivityBloc>().add(
          DisciplerActivityLoadRequested(
            fellowshipId: widget.fellowshipId,
            kind: kind,
          ),
        );
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
        centerTitle: true,
        title: Text(
          l10n.disciplerActivityTitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in <({String? kind, String label})>[
                    (kind: null, label: l10n.activityTabAll),
                    (kind: 'draft', label: l10n.activityTabReview),
                    (kind: 'reply', label: l10n.activityTabReplies),
                    (kind: 'react', label: l10n.activityTabReactions),
                    (kind: 'daily_post', label: l10n.activityTabDaily),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tab.label),
                        selected: _selectedKind == tab.kind,
                        onSelected: (_) => _selectKind(tab.kind),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<DisciplerActivityBloc, DisciplerActivityState>(
              builder: (context, state) {
                if (state.status == DisciplerActivityStatus.loading &&
                    state.items.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                if (state.status == DisciplerActivityStatus.failure &&
                    state.items.isEmpty) {
                  return Center(
                    child: Text(
                      state.errorMessage ?? l10n.feedLoadError,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  );
                }
                if (state.items.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.feedEmptyReadOnly,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(
                        item: state.items[index],
                        fellowshipId: widget.fellowshipId,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityCard
// ---------------------------------------------------------------------------

class _ActivityCard extends StatelessWidget {
  final DisciplerActivityEntity item;
  final String fellowshipId;

  const _ActivityCard({required this.item, required this.fellowshipId});

  ({String label, Color color}) _badgeFor(
    BuildContext context,
    String kind,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (kind) {
      case 'draft':
        return (
          label: l10n.activityKindDraft,
          color: isDark ? AppColors.warningLighter : AppColors.warningDark,
        );
      case 'reply':
        return (
          label: l10n.activityKindReplied,
          color: isDark ? AppColors.successLighter : AppColors.successDark,
        );
      case 'react':
        return (
          label: '${l10n.activityKindReacted} 🙏',
          color: context.appTextTertiary
        );
      case 'daily_post':
      case 'daily':
        return (
          label: l10n.activityKindDaily,
          color: isDark ? AppColors.warningLighter : AppColors.warningDark,
        );
      default:
        return (label: kind.toUpperCase(), color: context.appTextTertiary);
    }
  }

  void _openPost(BuildContext context) {
    if (item.postId == null) return;
    context.push('/community/$fellowshipId/post/${item.postId}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = _badgeFor(context, item.kind, isDark);
    final isDraft = item.kind == 'draft';
    final isReact = item.kind == 'react';

    return GestureDetector(
      onTap: item.postId != null ? () => _openPost(context) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorder.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DisciplerAvatar(radius: 14),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badge.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badge.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (item.language != null && item.language!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.appSurfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.language!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.summary,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: context.appTextPrimary,
              ),
            ),
            if (item.postContent != null && item.postContent!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${item.postContent}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: context.appTextSecondary,
                ),
              ),
            ],
            if (item.commentContent != null &&
                item.commentContent!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appPrimary.withAlpha(isDark ? 40 : 18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.commentContent!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isDraft && item.commentPending) ...[
                  GestureDetector(
                    onTap: () => context.read<DisciplerActivityBloc>().add(
                          DisciplerActivityReviewed(
                            commentId: item.commentId!,
                            approve: true,
                          ),
                        ),
                    child: Text(
                      l10n.approve,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appSuccess,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => context.read<DisciplerActivityBloc>().add(
                          DisciplerActivityReviewed(
                            commentId: item.commentId!,
                            approve: false,
                          ),
                        ),
                    child: Text(
                      l10n.discard,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appError,
                      ),
                    ),
                  ),
                ] else if (!isReact) ...[
                  GestureDetector(
                    onTap: () => context.read<DisciplerActivityBloc>().add(
                          DisciplerActivityDeleteRequested(
                            activityId: item.id,
                            postId: item.commentId == null ? item.postId : null,
                            commentId: item.commentId,
                          ),
                        ),
                    child: Text(
                      l10n.deleteAction,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appError,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
