import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../community/domain/entities/fellowship_entity.dart';
import '../../../community/domain/entities/fellowship_post_entity.dart';
import '../../../community/domain/entities/public_fellowship_entity.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../../community/presentation/widgets/discipler_badges.dart';

// ---------------------------------------------------------------------------
// Pure helpers (unit-tested in test/features/home/)
// ---------------------------------------------------------------------------

/// Leading emoji tag the Discipler's daily study post puts on its lesson-title
/// line. The body is plain text from the daily-post formatter: `📖` lesson
/// title, `✨` hook, body, `✝️` verse, `💬` question — `DailyPostCard` renders
/// them all in full. A home row only ever needs the title.
const String kDailyTitleTag = '📖';

/// One row of the home "Recent activity" list: a post plus the name of the
/// fellowship it came from.
class RecentActivityItem {
  final FellowshipPostEntity post;
  final String fellowshipName;

  const RecentActivityItem({required this.post, required this.fellowshipName});
}

/// Collapses all runs of whitespace (including newlines) into single spaces.
String _flatten(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

/// What kind of post a row points at. Rows are pointers, not previews, so the
/// kind — rather than the body — is what tells a reader whether to tap.
enum RecentActivityKind {
  daily,
  prayer,
  praise,
  question,
  studyNote,
  sharedGuide,
  general,
}

/// Maps a post onto the label its row should carry.
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
/// Returns null when there is nothing worth naming, in which case the row
/// shows only "Today's study".
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
/// skipped because their join button could only fail. Discovery order is
/// otherwise preserved.
List<PublicFellowshipEntity> pickSuggestedFellowships(
  List<PublicFellowshipEntity> discovered, {
  int limit = 2,
}) {
  if (limit <= 0) return const [];
  return discovered
      .where((f) => f.isOfficial)
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
  static const int _maxRows = 4;

  bool _loaded = false;
  List<RecentActivityItem> _items = const [];
  List<PublicFellowshipEntity> _suggestions = const [];
  String? _joiningId;

  @override
  void initState() {
    super.initState();
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
      if (!mounted) return;
      setState(() {
        _suggestions = pickSuggestedFellowships(discovered);
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
    final messenger = ScaffoldMessenger.of(context);

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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.homeJoinedFellowship(fellowship.name))),
      );
      context.push('/community/${fellowship.id}');
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeJoinFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_items.isNotEmpty) return _buildActivity(context);
    if (_suggestions.isNotEmpty) return _buildSuggestions(context);
    return const SizedBox.shrink();
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
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
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

/// Section title + optional trailing text action, matching the "For You"
/// header a little further up the page.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded container the rows sit inside. One panel of hairline-separated
/// rows reads as a single closing block, where three stacked cards at the
/// bottom of a long scroll would read as more page still to come.
class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 53),
        child: Container(height: 1, color: context.appDivider),
      );
}

/// Circular avatar for a human poster: their picture when they have one,
/// coloured initials otherwise.
class _MemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _MemberAvatar({required this.name, this.avatarUrl});

  static const List<Color> _palette = [
    Color(0xFF6A4FB6),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0].characters.first}${parts[1].characters.first}'
          .toUpperCase();
    }
    return parts[0].characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: _palette[hash % _palette.length],
        foregroundImage: NetworkImage(url),
        // Shown while the image loads and if it fails, so the row never
        // collapses to an empty disc.
        child: Text(
          _initials,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: _palette[hash % _palette.length],
      child: Text(
        _initials,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// One compact activity row: who posted, in which group, what kind of post,
/// and how long ago. Deliberately no body preview — the row is a pointer, and
/// tapping it opens the post itself.
class _ActivityRow extends StatelessWidget {
  final RecentActivityItem item;

  const _ActivityRow({required this.item});

  String _kindLabel(AppLocalizations l10n) {
    switch (recentActivityKind(item.post)) {
      case RecentActivityKind.daily:
        // The Discipler avatar and AI chip on the line above already say this
        // is the daily study, so the lesson title is the more useful half of
        // the label in the width a row has. Only unnamed lessons fall back to
        // the generic "Today's study".
        return dailyLessonTitle(item.post) ?? l10n.postTypeDaily;
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
    final post = item.post;
    final isDiscipler = post.authorIsSystem;
    final authorName =
        isDiscipler ? l10n.disciplerName : post.authorDisplayName;
    final time = recentActivityTimeLabel(l10n, post.createdAt);

    return Semantics(
      button: true,
      label: '$authorName · ${item.fellowshipName}',
      child: InkWell(
        onTap: () =>
            context.push('/community/${post.fellowshipId}/post/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: [
              // Discipler keeps its own mark so the daily study is
              // recognisable here without dragging the full gold card down to
              // this size.
              isDiscipler
                  ? const DisciplerAvatar(radius: 15)
                  : _MemberAvatar(
                      name: authorName,
                      avatarUrl: post.authorAvatarUrl,
                    ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            style: AppFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: context.appTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDiscipler) ...[
                          const SizedBox(width: 6),
                          const DisciplerAiChip(),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: AppFonts.inter(
                            fontSize: 11,
                            height: 1.25,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Group first and in the accent colour: at a glance the
                    // reader sees which room the voice is in, then what was
                    // said there.
                    // One greedy line: the group leads, the label follows.
                    // A proportional two-column split would ellipsize a long
                    // group name even when the rest of the line is empty, so
                    // the line is laid out as a single run and only its tail
                    // is trimmed when it genuinely runs out of room.
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.fellowshipName,
                            style: AppFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              color: context.appBrandAccent,
                            ),
                          ),
                          TextSpan(
                            text: '  ·  ${_kindLabel(l10n)}',
                            style: AppFonts.inter(
                              fontSize: 11.5,
                              height: 1.3,
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.appTextTertiary,
              ),
            ],
          ),
        ),
      ),
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
                          fontSize: 11.5,
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
                              fontSize: 11.5,
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
            _JoinButton(
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
          color: AppColors.brandHighlightDark,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final String label;
  final bool isJoining;
  final VoidCallback? onPressed;

  const _JoinButton({
    required this.label,
    required this.isJoining,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: isJoining ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appInteractive,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                context.appInteractive.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isJoining
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
}
