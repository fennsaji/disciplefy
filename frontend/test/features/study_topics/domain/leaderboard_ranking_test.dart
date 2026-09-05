import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/domain/entities/leaderboard_entry.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/leaderboard_ranking.dart';

/// "Your Rank" must equal the position the same user occupies in the padded
/// list. Each case builds the list with [LeaderboardRanking.merge] and checks
/// [LeaderboardRanking.rankWithPlaceholders] lands on the same number.
void main() {
  LeaderboardEntry real(String name, int xp, int dbRank, {bool me = false}) =>
      LeaderboardEntry(
        displayName: name,
        totalXp: xp,
        rank: dbRank,
        userId: 'uid-$name',
        isCurrentUser: me,
      );

  /// Rank of [name] in the merged list, or null if not shown.
  int? listRankOf(List<LeaderboardEntry> merged, String name) {
    for (final e in merged) {
      if (e.displayName == name && !e.isPlaceholder) return e.rank;
    }
    return null;
  }

  group('LeaderboardRanking', () {
    // The production board from the bug report: three real users among the
    // placeholders. parmesh S. is listed at #7 but his own pill said #5.
    final board = [
      real('Fenn S.', 4000, 1),
      real('Jagmal s.', 1125, 2),
      real('parmesh S.', 425, 3),
    ];

    test('pill rank matches list rank for every real user on a padded board',
        () {
      final merged = LeaderboardRanking.merge(board);
      expect(merged, hasLength(10));

      for (final user in board) {
        final pill = LeaderboardRanking.rankWithPlaceholders(
          dbRank: user.rank,
          userXp: user.totalXp,
          realRankedUserCount: board.length,
        );
        expect(pill, listRankOf(merged, user.displayName),
            reason: '${user.displayName} pill vs list');
      }
      // The concrete regression: real users above parmesh now count.
      expect(listRankOf(merged, 'parmesh S.'), 7);
    });

    test('a real user tied with a placeholder ranks ahead of it', () {
      final tied = [real('Someone', 600, 1)];
      final merged = LeaderboardRanking.merge(tied);
      expect(listRankOf(merged, 'Someone'), 1);
      expect(
        LeaderboardRanking.rankWithPlaceholders(
            dbRank: 1, userXp: 600, realRankedUserCount: 1),
        1,
      );
    });

    test('placeholders drop out once ten real users are ranked', () {
      final ten = [
        for (var i = 0; i < 10; i++) real('U$i', 1000 - i * 10, i + 1),
      ];
      final merged = LeaderboardRanking.merge(ten);
      expect(merged.every((e) => !e.isPlaceholder), isTrue);
      // A user ranked #12 by the database keeps that rank untouched.
      expect(
        LeaderboardRanking.rankWithPlaceholders(
            dbRank: 12, userXp: 850, realRankedUserCount: 10),
        12,
      );
    });

    test('a user below the ranked minimum has no rank', () {
      expect(
        LeaderboardRanking.rankWithPlaceholders(
            dbRank: null, userXp: 150, realRankedUserCount: 3),
        isNull,
      );
    });

    test('a ranked user pushed off the visible list still gets a rank', () {
      // 210 XP: every placeholder is above them, plus the three real users.
      expect(
        LeaderboardRanking.rankWithPlaceholders(
            dbRank: 4, userXp: 210, realRankedUserCount: 4),
        4 + LeaderboardRanking.placeholders.length,
      );
    });
  });
}
