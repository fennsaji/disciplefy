import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/fellowship_changes.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/reaction_button.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_sections.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested in test/features/home/)
// ---------------------------------------------------------------------------

/// Leading emoji tag the Discipler's daily study post puts on its lesson-title
/// line. The body is plain text from the daily-post formatter: `📖` lesson
/// title, `✨` hook, body, `✝️` verse, `💬` question — `DailyPostCard` renders
/// them all in full. A home row only ever needs the title.
const String kDailyTitleTag = '📖';

/// One row of the home "Community activity" list: a post plus the name of the
/// fellowship it came from.
class RecentActivityItem {
  final FellowshipPostEntity post;
  final String fellowshipName;

  const RecentActivityItem({required this.post, required this.fellowshipName});
}

/// Collapses all runs of whitespace (including newlines) into single spaces.
String _flatten(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// What kind of post a row shows: drives its type chip and accessible label.
enum RecentActivityKind {
  daily,
  prayer,
  praise,
  question,
  studyNote,
  sharedGuide,
  general,
}

/// Maps a post onto the kind its row should carry.
RecentActivityKind recentActivityKind(FellowshipPostEntity post) {
  if (post.isDaily) return RecentActivityKind.daily;
  switch (post.postType) {
    case 'prayer':
      return RecentActivityKind.prayer;
    case 'praise':
      return RecentActivityKind.praise;
    case 'question':
      return RecentActivityKind.question;
    case 'study_note':
      return RecentActivityKind.studyNote;
    case 'shared_guide':
      return RecentActivityKind.sharedGuide;
    default:
      return RecentActivityKind.general;
  }
}

/// Lesson title for the Discipler's daily study post.
///
/// Prefers the structured `topicTitle` / `guideTitle` the backend attaches;
/// falls back to the `📖` line of the emoji-tagged body when they are absent.
/// Returns null when there is nothing worth naming, in which case the row's
/// preview falls back to the lesson's opening line alone.
String? dailyLessonTitle(FellowshipPostEntity post) {
  for (final candidate in [post.topicTitle, post.guideTitle]) {
    if (candidate == null) continue;
    final flat = _flatten(candidate);
    if (flat.isNotEmpty) return flat;
  }
  for (final line in post.content.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith(kDailyTitleTag)) continue;
    final stripped = _flatten(trimmed.substring(kDailyTitleTag.length));
    if (stripped.isNotEmpty) return stripped;
  }
  return null;
}

/// Leading emoji tags the daily-post formatter puts on its structured lines.
const List<String> _dailyLineTags = ['📖', '✨', '✝️', '✝', '💬'];

/// Opening line of a daily study post under its title: the `✨` hook when
/// there is one, otherwise the first untagged body line. Null when neither
/// exists.
String? _dailyIntro(String content) {
  String? firstPlain;
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('✨')) {
      final hook = _flatten(line.substring('✨'.length));
      if (hook.isNotEmpty) return hook;
      continue;
    }
    if (_dailyLineTags.any(line.startsWith)) continue;
    firstPlain ??= _flatten(line);
  }
  return (firstPlain?.isEmpty ?? true) ? null : firstPlain;
}

/// Joins the non-empty parts with an em dash.
String _joinDash(List<String?> parts) => parts
    .whereType<String>()
    .map(_flatten)
    .where((p) => p.isNotEmpty)
    .join(' — ');

/// One-paragraph preview a home row shows under the author line.
///
/// - Daily study: lesson title, then its opening hook.
/// - Shared guide: guide title, then the sharer's message (or the guide's
///   summary when they wrote none).
/// - Everything else: the post body, whitespace collapsed.
///
/// Returns an empty string when the post has nothing to preview.
String recentActivityPreview(FellowshipPostEntity post) {
  if (post.isDaily) {
    return _joinDash([dailyLessonTitle(post), _dailyIntro(post.content)]);
  }
  if (post.postType == 'shared_guide') {
    final message = _flatten(post.content);
    return _joinDash([
      post.guideTitle,
      message.isNotEmpty ? message : post.guideSummary,
    ]);
  }
  return _flatten(post.content);
}

/// Total reactions across every emoji on [post]; negative counts are ignored.
int recentActivityReactionTotal(FellowshipPostEntity post) =>
    post.reactionCounts.values
        .fold<int>(0, (sum, count) => sum + (count > 0 ? count : 0));

/// Merges the per-fellowship post lists into a single newest-first list.
///
/// [postsPerFellowship] is positionally aligned with [fellowships] — the shape
/// `Future.wait` produces. Deleted posts are dropped, posts whose `createdAt`
/// cannot be parsed sort last (rather than crashing or jumping to the top),
/// and the result is capped at [limit].
List<RecentActivityItem> mergeRecentActivity(
  List<FellowshipEntity> fellowships,
  List<List<FellowshipPostEntity>> postsPerFellowship, {
  required int limit,
}) {
  final items = <({RecentActivityItem item, DateTime sortKey})>[];

  for (var i = 0;
      i < fellowships.length && i < postsPerFellowship.length;
      i++) {
    final fellowship = fellowships[i];
    for (final post in postsPerFellowship[i]) {
      if (post.isDeleted) continue;
      final parsed = DateTime.tryParse(post.createdAt)?.toUtc();
      items.add((
        item: RecentActivityItem(
          post: post,
          fellowshipName: fellowship.name,
        ),
        sortKey: parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ));
    }
  }

  items.sort((a, b) => b.sortKey.compareTo(a.sortKey));

  // Only the newest daily study per group earns a row. The Discipler posts one
  // every day, so without this a group with a quiet week fills the whole
  // section with its own back catalogue and crowds out the people.
  final seenDaily = <String>{};
  final result = <RecentActivityItem>[];
  for (final entry in items) {
    if (result.length >= (limit < 0 ? 0 : limit)) break;
    final post = entry.item.post;
    if (post.isDaily && !seenDaily.add(post.fellowshipId)) continue;
    result.add(entry.item);
  }
  return result;
}

/// Chooses which discovered groups to offer a user who has no fellowship yet.
///
/// Only official groups are suggested — they are mentored and run the daily
/// study, so they are the reliable first experience — and full ones are
/// skipped because their join button could only fail. Restricted to
/// [languageCode] so an English-speaking user is not offered "Disciplefy
/// Hindi" or "Disciplefy Malayalam" — a group whose daily study they cannot
/// read is worse than no suggestion at all. Discovery order is otherwise
/// preserved.
List<PublicFellowshipEntity> pickSuggestedFellowships(
  List<PublicFellowshipEntity> discovered, {
  required String languageCode,
  int limit = 2,
}) {
  if (limit <= 0) return const [];
  return discovered
      .where((f) => f.isOfficial)
      .where((f) => f.language == languageCode)
      .where((f) => f.isUnlimited || f.memberCount < (f.maxMembers ?? 0))
      .take(limit)
      .toList();
}

/// Relative timestamp for a post, using the same thresholds as the fellowship
/// feed's own timestamps but resolved through the localizations so Hindi and
/// Malayalam do not fall back to English.
String recentActivityTimeLabel(AppLocalizations l10n, String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.isNegative || diff.inSeconds < 60) return l10n.timeAgoJustNow;
  if (diff.inMinutes < 60) return l10n.timeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeAgoHours(diff.inHours);
  if (diff.inDays < 7) return l10n.timeAgoDays(diff.inDays);
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

// ---------------------------------------------------------------------------
// Section
// ---------------------------------------------------------------------------

/// Closing section of the home screen.
///
/// Shows the newest posts across every fellowship the user belongs to, or —
/// when they belong to none — a short invitation to join an official group.
/// Renders nothing at all while loading, on failure, or when the user has
/// groups but no posts: home must never close on a spinner or an empty shell.
class HomeCommunitySection extends StatefulWidget {
  const HomeCommunitySection({super.key});

  @override
  State<HomeCommunitySection> createState() => _HomeCommunitySectionState();
}

class _HomeCommunitySectionState extends State<HomeCommunitySection> {
  static const int _maxRows = 3;

  bool _loaded = false;

  /// True once the fellowship list came back (even empty). A failed lookup
  /// leaves it false and the section renders nothing, so an existing member
  /// is never invited to join a group they are already in.
  bool _lookupSucceeded = false;
  bool _isMember = false;
  List<RecentActivityItem> _items = const [];
  List<PublicFellowshipEntity> _suggestions = const [];
  String? _joiningId;

  @override
  void initState() {
    super.initState();
    _load();
    FellowshipChanges.instance.addListener(_reload);
  }

  @override
  void dispose() {
    FellowshipChanges.instance.removeListener(_reload);
    super.dispose();
  }

  /// Membership changed somewhere in the app: forget what was shown and ask
  /// again, so a group the user just joined stops being offered to them.
  void _reload() {
    if (!mounted) return;
    _lookupSucceeded = false;
    _isMember = false;
    _items = const [];
    _suggestions = const [];
    _load();
  }

  /// Study content language, matching the other two callers of
  /// `getFellowships` (`fellowship_list_bloc.dart`,
  /// `for_you_learning_paths_section.dart`). What this parameter selects is
  /// the translation of each fellowship's current learning-path title —
  /// generated study content, not UI chrome — so it follows the content axis.
  /// Falls back to English only if the preference cannot be read at all.
  Future<String> _resolveLanguageCode() async {
    try {
      final language =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      return language.code;
    } catch (_) {
      return 'en';
    }
  }

  Future<void> _load() async {
    try {
      final repo = sl<CommunityRepository>();
      // This does not filter the list — membership decides which fellowships
      // come back, so every group shows whatever language it is in. It only
      // picks which translation of each group's current learning-path title
      // is returned, so it has to follow the user's language rather than
      // being pinned to English.
      final language = await _resolveLanguageCode();
      final fellowshipsResult = await repo.getFellowships(language);

      // A failed lookup is not the same as belonging to no fellowship. Folding
      // the error into an empty list would invite an existing member to join a
      // group they are already in, so a failure renders nothing at all.
      final fellowships = fellowshipsResult.fold(
        (_) => null,
        (list) => list,
      );
      if (fellowships == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      _lookupSucceeded = true;
      _isMember = fellowships.isNotEmpty;

      if (fellowships.isEmpty) {
        await _loadSuggestions(repo);
        return;
      }

      // One request per group, in parallel; a failing group contributes an
      // empty list rather than sinking the whole section.
      final posts = await Future.wait(
        fellowships.map((f) async {
          try {
            final result = await repo.getFellowshipPosts(
              fellowshipId: f.id,
              limit: _maxRows,
            );
            return result.fold(
              (_) => <FellowshipPostEntity>[],
              (list) => list,
            );
          } catch (_) {
            return <FellowshipPostEntity>[];
          }
        }),
      );

      final merged = mergeRecentActivity(fellowships, posts, limit: _maxRows);
      if (!mounted) return;
      setState(() {
        _items = merged;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _loadSuggestions(CommunityRepository repo) async {
    try {
      final page = await repo.discoverFellowships();
      final discovered = page.fold(
        (_) => <PublicFellowshipEntity>[],
        (p) => p.fellowships,
      );
      // The app's UI language, not the study-content language: a group's
      // whole point is a daily study its members can actually discuss
      // together, so it must match the language the person is using the app
      // in, not whichever translation happened to be picked for content.
      final language = await sl<LanguagePreferenceService>()
          .getSelectedLanguage()
          .then((l) => l.code)
          .catchError((_) => 'en');
      if (!mounted) return;
      setState(() {
        _suggestions =
            pickSuggestedFellowships(discovered, languageCode: language);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _join(PublicFellowshipEntity fellowship) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = fellowship.id);
    final l10n = AppLocalizations.of(context)!;

    bool ok = false;
    try {
      final result =
          await sl<CommunityRepository>().joinPublicFellowship(fellowship.id);
      ok = result.isRight();
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() => _joiningId = null);

    if (ok) {
      showAppSnackBar(
        context,
        l10n.homeJoinedFellowship(fellowship.name),
        tone: AppSnackTone.success,
      );
      context.push('/community/${fellowship.id}');
    } else {
      showAppSnackBar(context, l10n.homeJoinFailed, tone: AppSnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_items.isNotEmpty) return _buildActivity(context);
    if (_suggestions.isNotEmpty) return _buildSuggestions(context);
    if (!_lookupSucceeded) return const SizedBox.shrink();
    return _buildEmpty(context);
  }

  // ── Case C: nothing to list yet ────────────────────────────────────────
  //
  // A member whose groups have no posts, or a non-member with no group to
  // suggest: the section still closes the page, with one row that says what
  // to do next instead of disappearing.

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final member = _isMember;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: member
              ? l10n.homeRecentActivityTitle
              : l10n.homeJoinFellowshipTitle,
          subtitle: member
              ? l10n.homeRecentActivitySubtitle
              : l10n.homeJoinFellowshipSubtitle,
          actionLabel:
              member ? l10n.homeCommunityViewAll : l10n.homeCommunityBrowse,
          onAction: () => context.go(AppRoutes.community),
        ),
        const SizedBox(height: 12),
        _Panel(
          children: [
            _EmptyRow(
              key: const Key('home_activity_empty_row'),
              icon: member
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.groups_outlined,
              title: member
                  ? l10n.homeActivityEmptyTitle
                  : l10n.homeBrowseFellowships,
              subtitle: member
                  ? l10n.homeActivityEmptyHint
                  : l10n.homeBrowseFellowshipsHint,
              onTap: () => context.go(AppRoutes.community),
            ),
          ],
        ),
      ],
    );
  }

  // ── Case A: recent activity ────────────────────────────────────────────

  Widget _buildActivity(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeRecentActivityTitle,
          subtitle: l10n.homeRecentActivitySubtitle,
          actionLabel: l10n.homeCommunityViewAll,
          onAction: () => context.go(AppRoutes.community),
        ),
        const SizedBox(height: 12),
        _Panel(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const _RowDivider(),
              _ActivityRow(item: _items[i]),
            ],
          ],
        ),
      ],
    );
  }

  // ── Case B: join a fellowship ──────────────────────────────────────────

  Widget _buildSuggestions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeJoinFellowshipTitle,
          subtitle: l10n.homeJoinFellowshipSubtitle,
          actionLabel: l10n.homeCommunityBrowse,
          onAction: () => context.go(AppRoutes.community),
        ),
        const SizedBox(height: 12),
        _Panel(
          children: [
            for (var i = 0; i < _suggestions.length; i++) ...[
              if (i > 0) const _RowDivider(),
              _SuggestionRow(
                fellowship: _suggestions[i],
                isJoining: _joiningId == _suggestions[i].id,
                isBusy: _joiningId != null,
                onJoin: () => _join(_suggestions[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Presentation pieces
// ---------------------------------------------------------------------------

/// Section title + trailing text action, built on the shared home header so
/// every heading under the hero lines up. The action is drawn in the brand
/// accent: this is the one section whose "View all" leaves the home tab.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return HomeSectionHeader(
      title: title,
      subtitle: subtitle,
      trailing: TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          actionLabel,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.accentIcon,
          ),
        ),
      ),
    );
  }
}

/// Rounded card the rows sit inside. One panel of hairline-separated rows
/// reads as a single closing block, where three stacked cards at the bottom
/// of a long scroll would read as more page still to come.
class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Hairline between panel rows, inset to the rows' horizontal padding.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          height: 1,
          color: ReaderPalette.of(context).hairline,
        ),
      );
}

/// One activity item: who posted and when, what kind of post, a short
/// preview of what was said, and which group it was said in. The whole row
/// opens the post.
class _ActivityRow extends StatelessWidget {
  final RecentActivityItem item;

  const _ActivityRow({required this.item});

  /// Accessible name of the post kind, including general posts, which carry
  /// no visible chip.
  String _kindLabel(AppLocalizations l10n) {
    switch (recentActivityKind(item.post)) {
      case RecentActivityKind.daily:
        return l10n.postTypeDaily;
      case RecentActivityKind.prayer:
        return l10n.postTypePrayer;
      case RecentActivityKind.praise:
        return l10n.postTypePraise;
      case RecentActivityKind.question:
        return l10n.postTypeQuestion;
      case RecentActivityKind.studyNote:
        return l10n.postTypeStudyNote;
      case RecentActivityKind.sharedGuide:
        return l10n.postTypeSharedGuide;
      case RecentActivityKind.general:
        return l10n.homeActivityPosted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final post = item.post;
    final isDiscipler = post.authorIsSystem;
    final authorName =
        isDiscipler ? l10n.disciplerName : post.authorDisplayName;
    final time = recentActivityTimeLabel(l10n, post.createdAt);
    final preview = recentActivityPreview(post);

    return Semantics(
      button: true,
      label: '$authorName · ${_kindLabel(l10n)} · ${item.fellowshipName}',
      child: InkWell(
        onTap: () =>
            context.push('/community/${post.fellowshipId}/post/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The Discipler keeps its own gold mark so the daily study is
              // recognisable at a glance.
              if (isDiscipler)
                const DisciplerAvatar(radius: 18)
              else
                MemberAvatar(
                  displayName: authorName,
                  avatarUrl: post.authorAvatarUrl,
                  radius: 18,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActivityHeadline(
                      authorName: authorName,
                      time: time,
                      postType: post.postType,
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _ActivityPreview(
                        preview: preview,
                        // Daily studies are summarised by design; only a
                        // member's own words need the "Read more" cue.
                        showReadMore: !post.isDaily,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _ActivityMeta(
                      fellowshipName: item.fellowshipName,
                      post: post,
                      palette: palette,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two-line preview under a home activity row. The row is a compact
/// summary, so the text is clamped — but when it is, an ellipsis and a
/// "Read more" cue make that plain (tapping the row opens the full post).
class _ActivityPreview extends StatelessWidget {
  final String preview;
  final bool showReadMore;

  const _ActivityPreview({required this.preview, required this.showReadMore});

  static const int _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final base = AppFonts.inter(
      fontSize: 13.5,
      height: 1.45,
      color: context.appTextSecondary,
    );
    final span = TextSpan(
      children: mentionSpans(
        preview,
        base,
        base.copyWith(fontWeight: FontWeight.w600, color: palette.accentIcon),
      ),
    );
    final text = Text.rich(
      span,
      key: const Key('home_activity_preview'),
      maxLines: _maxLines,
      overflow: TextOverflow.ellipsis,
    );
    if (!showReadMore) return text;

    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: span,
        maxLines: _maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      if (!overflows) return text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.feedReadMore,
            key: const Key('home_activity_read_more'),
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.accentIcon,
            ),
          ),
        ],
      );
    });
  }
}

/// Name, time and — on the right — the post-type chip.
class _ActivityHeadline extends StatelessWidget {
  final String authorName;
  final String time;
  final String postType;

  const _ActivityHeadline({
    required this.authorName,
    required this.time,
    required this.postType,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      time,
                      maxLines: 1,
                      style: AppFonts.inter(
                        fontSize: 12,
                        height: 1.3,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Capped so a long localized label wraps inside the chip rather
            // than squeezing the author's name to nothing; never cut.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
              child: PostTypeChip(postType: postType),
            ),
          ],
        );
      },
    );
  }
}

/// Group name in gold, then reply and reaction counts — or, for the daily
/// study, the invitation to start it.
class _ActivityMeta extends StatelessWidget {
  final String fellowshipName;
  final FellowshipPostEntity post;
  final ReaderPalette palette;

  const _ActivityMeta({
    required this.fellowshipName,
    required this.post,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppFonts.inter(
      fontSize: 12,
      height: 1.35,
      color: context.appTextTertiary,
    );

    final Widget? trailing;
    if (post.isDaily) {
      trailing = Text(
        '·  ${context.tr(TranslationKeys.communitySharedStartStudy)}',
        style: AppFonts.inter(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: palette.accentIcon,
        ),
      );
    } else {
      final replies = post.commentCount;
      final reactions = recentActivityReactionTotal(post);
      trailing = replies <= 0 && reactions <= 0
          ? null
          : Text.rich(
              TextSpan(
                style: metaStyle,
                children: [
                  const TextSpan(text: '·  '),
                  if (replies > 0)
                    TextSpan(text: postRepliesLabel(context, replies)),
                  if (replies > 0 && reactions > 0)
                    const TextSpan(text: '  ·  '),
                  if (reactions > 0) ...[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        reactionOptions.first.icon,
                        size: 13,
                        color: metaStyle.color,
                      ),
                    ),
                    TextSpan(text: ' $reactions'),
                  ],
                ],
              ),
            );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // A wrap, not a row: when the group name and the counts do not both
        // fit, the counts drop to the next line instead of being cut.
        return Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 14, color: palette.gold),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      fellowshipName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: palette.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        );
      },
    );
  }
}

/// One suggested official group, with a direct join affordance.
class _SuggestionRow extends StatelessWidget {
  final PublicFellowshipEntity fellowship;
  final bool isJoining;
  final bool isBusy;
  final VoidCallback onJoin;

  const _SuggestionRow({
    required this.fellowship,
    required this.isJoining,
    required this.isBusy,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => context.push('/community/${fellowship.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          fellowship.name,
                          style: AppFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const _OfficialPill(),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 12, color: context.appTextTertiary),
                      const SizedBox(width: 4),
                      Text(
                        l10n.homeMembersCount(fellowship.memberCount),
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: context.appTextTertiary,
                        ),
                      ),
                      if ((fellowship.mentorName ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: context.appTextTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            fellowship.mentorName!,
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: context.appTextTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            HomeJoinPill(
              label: l10n.homeJoinFellowshipCta,
              isJoining: isJoining,
              onPressed: isBusy ? null : onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialPill extends StatelessWidget {
  const _OfficialPill();

  /// The dark gold deepened to 4.5:1 on the cream pill (it measured 2.8:1).
  static const Color _ink = Color(0xFF8D6608);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandHighlight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandHighlightDark.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        l10n.officialBadge,
        style: AppFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// "Join" pill on a public-fellowship suggestion: primary CTA colours,
/// with a spinner while the join is in flight.
class HomeJoinPill extends StatelessWidget {
  final String label;
  final bool isJoining;
  final VoidCallback? onPressed;

  const HomeJoinPill({
    super.key,
    required this.label,
    required this.isJoining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: FilledButton(
        onPressed: isJoining ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.ctaFill,
          foregroundColor: palette.ctaInk,
          disabledBackgroundColor: palette.ctaFill.withValues(alpha: 0.5),
          disabledForegroundColor: palette.ctaInk,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
        child: isJoining
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.ctaInk),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.ctaInk,
                ),
              ),
      ),
    );
  }
}

/// Single call-to-action row for the empty activity panel.
class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EmptyRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: accent),
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
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18, color: context.appTextSecondary),
          ],
        ),
      ),
    );
  }
}
