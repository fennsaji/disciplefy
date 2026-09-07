import '../../domain/entities/fellowship_post_entity.dart';

/// Sorts [posts] so that today's daily study post (if any) appears first,
/// followed by the rest of the feed in its existing (newest-first) order.
///
/// [now] defaults to [DateTime.now] and is injectable for tests.
List<FellowshipPostEntity> sortFeed(
  List<FellowshipPostEntity> posts, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();

  bool isTodayDaily(FellowshipPostEntity post) {
    if (!post.isDaily) return false;
    final created = DateTime.tryParse(post.createdAt);
    if (created == null) return false;
    final local = created.toLocal();
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }

  // Partition (rather than List.sort, which isn't guaranteed stable) so the
  // relative order within each group is preserved.
  final todayDaily = <FellowshipPostEntity>[];
  final rest = <FellowshipPostEntity>[];
  for (final post in posts) {
    if (isTodayDaily(post)) {
      todayDaily.add(post);
    } else {
      rest.add(post);
    }
  }
  return [...todayDaily, ...rest];
}
