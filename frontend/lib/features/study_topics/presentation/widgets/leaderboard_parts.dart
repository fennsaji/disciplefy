import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/leaderboard_entry.dart';

const Color _silver = Color(0xFFB0BEC5);
const Color _bronze = Color(0xFFCD8B5A);

/// Up to two initials from a display name ("Rahul Varghese" → "RV").
String leaderboardInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  if (words.length == 1) return first.toUpperCase();
  final last = words.last.replaceAll('.', '');
  return (first + (last.isEmpty ? '' : last.characters.first)).toUpperCase();
}

/// "XP needed to pass the person one rank above" for the current user, or
/// null when the user is unranked, first, or that entry is not loaded.
({int xp, String name})? leaderboardGapAbove(
  List<LeaderboardEntry> entries,
  UserXpRank userRank,
) {
  final rank = userRank.rank;
  if (rank == null || rank <= 1) return null;
  for (final entry in entries) {
    if (entry.rank == rank - 1 && !entry.isCurrentUser) {
      final gap = entry.totalXp - userRank.totalXp + 1;
      final firstName = entry.displayName.trim().split(RegExp(r'\s+')).first;
      return (xp: gap < 1 ? 1 : gap, name: firstName);
    }
  }
  return null;
}

/// Back arrow and Poppins page title over the photo wash.
class LeaderboardTitleBar extends StatelessWidget {
  final VoidCallback onBack;

  const LeaderboardTitleBar({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: palette.text),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              context.tr(TranslationKeys.leaderboardTitle),
              style: AppFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top three on stepped platforms: 2nd, 1st, 3rd.
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardPodium({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox(height: 16);
    final palette = ReaderPalette.of(context);
    LeaderboardEntry? at(int i) => entries.length > i ? entries[i] : null;

    Widget slot(LeaderboardEntry? entry, int rank, Color color, double h) =>
        Expanded(
          child: entry == null
              ? const SizedBox()
              : _PodiumItem(
                  entry: entry,
                  rank: rank,
                  color: color,
                  platformHeight: h,
                ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          slot(at(1), 2, _silver, 76),
          const SizedBox(width: 10),
          slot(at(0), 1, palette.gold, 100),
          const SizedBox(width: 10),
          slot(at(2), 3, _bronze, 62),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final Color color;
  final double platformHeight;

  const _PodiumItem({
    required this.entry,
    required this.rank,
    required this.color,
    required this.platformHeight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isFirst = rank == 1;
    final size = isFirst ? 60.0 : 50.0;

    return Semantics(
      label: '#$rank ${entry.displayName}, ${entry.totalXp} XP',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: palette.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst ? palette.gold : palette.outline,
                width: isFirst ? 2 : 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              leaderboardInitials(entry.displayName),
              style: AppFonts.poppins(
                fontSize: isFirst ? 18 : 15,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.displayName,
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: entry.isCurrentUser ? palette.accentIcon : palette.text,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            height: platformHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withValues(alpha: palette.isDark ? 0.22 : 0.26),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            padding: const EdgeInsets.only(top: 8),
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text(
                    '$rank',
                    style: AppFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: isFirst ? palette.gold : palette.text,
                    ),
                  ),
                  Text(
                    '${entry.totalXp} XP',
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ranked person below the podium; the current user's row is
/// outlined in the brand colour.
class LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const LeaderboardRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final mine = entry.isCurrentUser;
    final brand = palette.selectedFill;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: mine
            ? brand.withValues(alpha: palette.isDark ? 0.2 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: mine
            ? Border.all(
                color: brand.withValues(alpha: palette.isDark ? 0.9 : 0.5),
                width: 1.2,
              )
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.raised,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              leaderboardInitials(entry.displayName),
              style: AppFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.displayName,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: mine ? FontWeight.w600 : FontWeight.w500,
                color: palette.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.totalXp} XP',
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned card with the current user's rank, XP and the gap to the next
/// person up.
class LeaderboardUserRankBar extends StatelessWidget {
  final UserXpRank userRank;

  /// XP needed to pass the person one rank above, if known.
  final ({int xp, String name})? gapAbove;

  const LeaderboardUserRankBar({
    super.key,
    required this.userRank,
    this.gapAbove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final gap = gapAbove;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up_rounded,
                color: context.appSuccess, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(TranslationKeys.leaderboardYourRank),
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  if (gap != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.leaderboardXpToPass,
                          {'xp': gap.xp, 'name': gap.name}),
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userRank.isRanked ? '#${userRank.rank}' : '–',
                    style: AppFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 1,
                    height: 14,
                    color: palette.outline,
                  ),
                  Text(
                    '${userRank.totalXp} XP',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
