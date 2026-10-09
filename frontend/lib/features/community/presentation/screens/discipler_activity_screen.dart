import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/discipler_activity_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/discipler_activity/discipler_activity_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_edit_dialog.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';

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
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: CommunityBackBar(
        title: l10n.disciplerActivityTitle,
        background: palette.page,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                    child: CommunityRaisedPill(
                      label: tab.label,
                      selected: _selectedKind == tab.kind,
                      onPressed: () => _selectKind(tab.kind),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<DisciplerActivityBloc, DisciplerActivityState>(
              builder: (context, state) {
                if (state.status == DisciplerActivityStatus.loading &&
                    state.items.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: palette.accentIcon),
                  );
                }
                if (state.status == DisciplerActivityStatus.failure &&
                    state.items.isEmpty) {
                  return _ActivityMessage(
                    text: state.errorMessage ?? l10n.feedLoadError,
                  );
                }
                if (state.items.isEmpty) {
                  return _ActivityMessage(text: l10n.feedEmptyReadOnly);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: palette.accentIcon,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

class _ActivityMessage extends StatelessWidget {
  final String text;

  const _ActivityMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DisciplerAvatar(radius: 24),
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
          ],
        ),
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

  ({String label, SettingsTone tone}) _badgeFor(
    BuildContext context,
    String kind,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (kind) {
      case 'draft':
        return (label: l10n.activityKindDraft, tone: SettingsTone.amber);
      case 'reply':
        return (label: l10n.activityKindReplied, tone: SettingsTone.green);
      case 'react':
        return (label: l10n.activityKindReacted, tone: SettingsTone.gold);
      case 'daily_post':
      case 'daily':
        return (label: l10n.activityKindDaily, tone: SettingsTone.gold);
      default:
        return (label: kind.toUpperCase(), tone: SettingsTone.gold);
    }
  }

  void _openPost(BuildContext context) {
    if (item.postId == null) return;
    context.push('/community/$fellowshipId/post/${item.postId}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final badge = _badgeFor(context, item.kind);
    final badgeColors = SettingsToneColors.of(context, badge.tone);
    final isDraft = item.kind == 'draft';
    final isReact = item.kind == 'react';
    final red = SettingsToneColors.of(context, SettingsTone.red).foreground;
    final green = SettingsToneColors.of(context, SettingsTone.green).foreground;

    final actions = <Widget>[
      if (isDraft && item.commentPending) ...[
        _CardAction(
          label: l10n.approve,
          color: green,
          onTap: () => context.read<DisciplerActivityBloc>().add(
                DisciplerActivityReviewed(
                  commentId: item.commentId!,
                  approve: true,
                ),
              ),
        ),
        _CardAction(
          label: l10n.discard,
          color: red,
          onTap: () => context.read<DisciplerActivityBloc>().add(
                DisciplerActivityReviewed(
                  commentId: item.commentId!,
                  approve: false,
                ),
              ),
        ),
      ] else if (!isReact && !item.hasLiveContent) ...[
        // Nothing left to edit or delete: the post was replaced by
        // "Post again" or already removed, or the row never had one.
        if (item.postId != null || item.commentId != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.dailyPostPostDeleted,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.dim,
              ),
            ),
          ),
      ] else if (!isReact) ...[
        if ((item.commentContent ?? item.postContent)?.isNotEmpty ?? false)
          _CardAction(
            label: l10n.editAction,
            color: palette.accentIcon,
            onTap: () async {
              final bloc = context.read<DisciplerActivityBloc>();
              final text = await showDisciplerEditDialog(
                context,
                initialText: item.commentContent ?? item.postContent!,
                maxLength: item.commentId != null ? 2000 : 4000,
              );
              if (text == null) return;
              bloc.add(DisciplerActivityEditRequested(
                activityId: item.id,
                postId: item.commentId == null ? item.postId : null,
                commentId: item.commentId,
                content: text,
              ));
            },
          ),
        _CardAction(
          label: l10n.deleteAction,
          color: red,
          onTap: () => context.read<DisciplerActivityBloc>().add(
                DisciplerActivityDeleteRequested(
                  activityId: item.id,
                  postId: item.commentId == null ? item.postId : null,
                  commentId: item.commentId,
                ),
              ),
        ),
      ],
    ];

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: item.postId != null && !item.postDeleted
            ? () => _openPost(context)
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DisciplerAvatar(radius: 15),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Badge(
                          label: badge.label,
                          fill: badgeColors.fill,
                          ink: badgeColors.foreground,
                        ),
                        if (item.language != null && item.language!.isNotEmpty)
                          _Badge(
                            label: item.language!.toUpperCase(),
                            fill: palette.raised,
                            ink: palette.muted,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.summary,
                style: AppFonts.inter(
                  fontSize: 14.5,
                  color: palette.text,
                  height: 1.45,
                ),
              ),
              if (item.postContent != null && item.postContent!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${item.postContent}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ],
              if (item.commentContent != null &&
                  item.commentContent!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item.commentContent!,
                    style: AppFonts.inter(
                      fontSize: 13.5,
                      color: palette.text,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              if (actions.isEmpty)
                const SizedBox(height: 10)
              else
                Wrap(spacing: 4, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;

  const _Badge({required this.label, required this.fill, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// 44px-tall text action at the foot of an activity card.
class _CardAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CardAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        label,
        style: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
