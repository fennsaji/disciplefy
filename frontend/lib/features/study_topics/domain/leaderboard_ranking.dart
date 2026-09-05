import 'entities/leaderboard_entry.dart';

/// Placeholder accounts and the rank arithmetic shared by the Leaderboard page
/// and My Progress, so every surface agrees on "Your Rank".
///
/// While fewer than [visibleEntries] real users have reached [minRankedXp],
/// the leaderboard pads itself with [placeholders] to look like an active
/// community. A user's rank must therefore count both the real users above
/// them (the database rank) and the placeholders above them — counting only
/// one of the two, as the two call sites previously did independently, makes
/// the "Your Rank" pill disagree with the list it sits under.
class LeaderboardRanking {
  LeaderboardRanking._();

  /// Minimum XP to appear on the leaderboard at all.
  static const int minRankedXp = 200;

  /// Rows the leaderboard shows; placeholders drop out once this many real
  /// users are ranked.
  static const int visibleEntries = 10;

  /// Fixed placeholder accounts. XP values are above [minRankedXp], multiples
  /// of 50, and well spaced.
  static const List<({String name, int xp})> placeholders = [
    (name: 'Rahul Sharma', xp: 600),
    (name: 'Priya Nair', xp: 550),
    (name: 'Amit Patel', xp: 500),
    (name: 'Sneha Iyer', xp: 450),
    (name: 'Vikram Reddy', xp: 400),
    (name: 'Anjali Thomas', xp: 350),
    (name: 'Suresh Kumar', xp: 300),
    (name: 'Meera Menon', xp: 300),
    (name: 'Rajesh Gupta', xp: 250),
    (name: 'Divya Joseph', xp: 250),
  ];

  /// Whether placeholders are part of the board given how many real users are
  /// ranked.
  static bool placeholdersInPlay(int realRankedUserCount) =>
      realRankedUserCount < visibleEntries;

  /// The rank a user with [userXp] holds on the padded board.
  ///
  /// [dbRank] is the 1-based rank among real ranked users as the database
  /// reports it (null when the user is below [minRankedXp]). Placeholders with
  /// strictly more XP push the user down; a placeholder tied on XP does not,
  /// matching [merge], which keeps real entries ahead of placeholders on ties.
  static int? rankWithPlaceholders({
    required int? dbRank,
    required int userXp,
    required int realRankedUserCount,
  }) {
    if (dbRank == null || userXp < minRankedXp) return null;
    if (!placeholdersInPlay(realRankedUserCount)) return dbRank;
    final placeholdersAbove = placeholders.where((p) => p.xp > userXp).length;
    return dbRank + placeholdersAbove;
  }

  /// Pads [realEntries] (already ordered by rank) with placeholders, sorts by
  /// XP and returns the top [visibleEntries] with ranks reassigned.
  ///
  /// Real entries are added first so the stable sort keeps them ahead of any
  /// placeholder they tie with. A placeholder whose name collides with a real
  /// user is skipped.
  static List<LeaderboardEntry> merge(List<LeaderboardEntry> realEntries) {
    if (!placeholdersInPlay(realEntries.length)) return realEntries;

    final usedNames = realEntries.map((e) => e.displayName).toSet();
    final combined = <LeaderboardEntry>[
      ...realEntries,
      for (final p in placeholders)
        if (usedNames.add(p.name))
          LeaderboardEntry.placeholder(
              displayName: p.name, totalXp: p.xp, rank: 0),
    ]..sort((a, b) => b.totalXp.compareTo(a.totalXp));

    return [
      for (var i = 0; i < combined.length && i < visibleEntries; i++)
        combined[i].isPlaceholder
            ? LeaderboardEntry.placeholder(
                displayName: combined[i].displayName,
                totalXp: combined[i].totalXp,
                rank: i + 1,
              )
            : LeaderboardEntry(
                displayName: combined[i].displayName,
                totalXp: combined[i].totalXp,
                rank: i + 1,
                userId: combined[i].userId,
                isCurrentUser: combined[i].isCurrentUser,
              ),
    ];
  }
}
