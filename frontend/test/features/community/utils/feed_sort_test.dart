import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/feed_sort.dart';

FellowshipPostEntity _post(
  String id, {
  String type = 'general',
  required String createdAt,
}) =>
    FellowshipPostEntity(
      id: id,
      fellowshipId: 'f',
      authorUserId: 'a',
      content: 'c',
      postType: type,
      reactionCounts: const {},
      isDeleted: false,
      createdAt: createdAt,
      authorDisplayName: 'a',
      commentCount: 0,
    );

void main() {
  final now = DateTime(2026, 9, 6, 12);

  test('moves today\'s daily post to the front', () {
    final posts = [
      _post('p1', createdAt: '2026-09-06T10:00:00Z'),
      _post('daily', type: 'daily', createdAt: '2026-09-06T09:00:00Z'),
      _post('p2', createdAt: '2026-09-05T10:00:00Z'),
    ];

    final sorted = sortFeed(posts, now: now);

    expect(sorted.map((p) => p.id), ['daily', 'p1', 'p2']);
  });

  test('does not reorder a stale (not-today) daily post', () {
    final posts = [
      _post('p1', createdAt: '2026-09-06T10:00:00Z'),
      _post('daily', type: 'daily', createdAt: '2026-09-01T09:00:00Z'),
    ];

    final sorted = sortFeed(posts, now: now);

    expect(sorted.map((p) => p.id), ['p1', 'daily']);
  });

  test('preserves relative order otherwise', () {
    final posts = [
      _post('p1', createdAt: '2026-09-06T10:00:00Z'),
      _post('p2', createdAt: '2026-09-05T10:00:00Z'),
      _post('p3', createdAt: '2026-09-04T10:00:00Z'),
    ];

    final sorted = sortFeed(posts, now: now);

    expect(sorted.map((p) => p.id), ['p1', 'p2', 'p3']);
  });
}
