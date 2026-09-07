import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_community_section.dart';
import 'package:flutter_test/flutter_test.dart';

FellowshipEntity _fellowship(String id, String name) => FellowshipEntity(
      id: id,
      name: name,
      memberCount: 4,
      userRole: 'member',
      joinedAt: '2026-01-01T00:00:00Z',
      createdAt: '2026-01-01T00:00:00Z',
    );

FellowshipPostEntity _post({
  required String id,
  String fellowshipId = 'f1',
  String content = 'hello',
  String postType = 'general',
  String createdAt = '2026-09-06T10:00:00Z',
  String authorUserId = 'user-1',
  bool isDeleted = false,
  String? topicTitle,
  String? guideTitle,
}) =>
    FellowshipPostEntity(
      id: id,
      fellowshipId: fellowshipId,
      authorUserId: authorUserId,
      content: content,
      postType: postType,
      reactionCounts: const {},
      isDeleted: isDeleted,
      createdAt: createdAt,
      authorDisplayName: 'Ann',
      commentCount: 0,
      topicTitle: topicTitle,
      guideTitle: guideTitle,
    );

PublicFellowshipEntity _public({
  required String id,
  bool isOfficial = true,
  int memberCount = 3,
  int? maxMembers,
}) =>
    PublicFellowshipEntity(
      id: id,
      name: 'Group $id',
      language: 'en',
      memberCount: memberCount,
      maxMembers: maxMembers,
      isOfficial: isOfficial,
    );

void main() {
  group('recentActivityKind', () {
    test('maps each post type onto its label kind', () {
      expect(recentActivityKind(_post(id: '1', postType: 'daily')),
          RecentActivityKind.daily);
      expect(recentActivityKind(_post(id: '2', postType: 'prayer')),
          RecentActivityKind.prayer);
      expect(recentActivityKind(_post(id: '3', postType: 'praise')),
          RecentActivityKind.praise);
      expect(recentActivityKind(_post(id: '4', postType: 'question')),
          RecentActivityKind.question);
      expect(recentActivityKind(_post(id: '5', postType: 'study_note')),
          RecentActivityKind.studyNote);
      expect(recentActivityKind(_post(id: '6', postType: 'shared_guide')),
          RecentActivityKind.sharedGuide);
    });

    test('falls back to general for unknown types', () {
      expect(recentActivityKind(_post(id: '7', postType: 'something_new')),
          RecentActivityKind.general);
    });
  });

  group('dailyLessonTitle', () {
    test('prefers the structured topic title', () {
      final post = _post(
        id: '1',
        postType: 'daily',
        topicTitle: 'The Vine and the Branches',
        guideTitle: 'Gospel of John',
        content: '📖 Something else\n✨ A hook',
      );
      expect(dailyLessonTitle(post), 'The Vine and the Branches');
    });

    test('falls back to the guide title', () {
      final post = _post(
        id: '1',
        postType: 'daily',
        guideTitle: 'Gospel of John',
        content: '✨ A hook',
      );
      expect(dailyLessonTitle(post), 'Gospel of John');
    });

    test('reads the 📖 line when no structured title exists', () {
      final post = _post(
        id: '1',
        postType: 'daily',
        content: '📖  Living Water \n✨ Hook line\n✝️ John 4:14\n💬 Question?',
      );
      expect(dailyLessonTitle(post), 'Living Water');
    });

    test('collapses newlines and repeated spaces in a title', () {
      final post = _post(
        id: '1',
        postType: 'daily',
        topicTitle: 'Living   Water\nand Bread',
      );
      expect(dailyLessonTitle(post), 'Living Water and Bread');
    });

    test('returns null when there is no title anywhere', () {
      final post = _post(
        id: '1',
        postType: 'daily',
        content: '✨ Hook only\n💬 Question?',
      );
      expect(dailyLessonTitle(post), isNull);
    });

    test('ignores a 📖 line that is empty after the tag', () {
      final post = _post(id: '1', postType: 'daily', content: '📖   \n✨ Hook');
      expect(dailyLessonTitle(post), isNull);
    });
  });

  group('mergeRecentActivity', () {
    test('merges groups and sorts newest first', () {
      final fellowships = [
        _fellowship('f1', 'Morning'),
        _fellowship('f2', 'Evening')
      ];
      final posts = [
        [
          _post(id: 'a', createdAt: '2026-09-06T08:00:00Z'),
          _post(id: 'b', createdAt: '2026-09-05T08:00:00Z'),
        ],
        [
          _post(id: 'c', fellowshipId: 'f2', createdAt: '2026-09-06T12:00:00Z'),
        ],
      ];

      final merged = mergeRecentActivity(fellowships, posts, limit: 5);
      expect(merged.map((e) => e.post.id), ['c', 'a', 'b']);
      expect(merged.first.fellowshipName, 'Evening');
      expect(merged[1].fellowshipName, 'Morning');
    });

    test('caps the result at the limit', () {
      final fellowships = [_fellowship('f1', 'Morning')];
      final posts = [
        [
          for (var i = 0; i < 10; i++)
            _post(id: '$i', createdAt: '2026-09-0${i % 9 + 1}T08:00:00Z'),
        ],
      ];
      expect(mergeRecentActivity(fellowships, posts, limit: 3).length, 3);
      expect(mergeRecentActivity(fellowships, posts, limit: 0), isEmpty);
    });

    test('drops deleted posts', () {
      final merged = mergeRecentActivity(
        [_fellowship('f1', 'Morning')],
        [
          [
            _post(id: 'a', isDeleted: true),
            _post(id: 'b'),
          ]
        ],
        limit: 5,
      );
      expect(merged.map((e) => e.post.id), ['b']);
    });

    test('sorts posts with an unparseable timestamp last', () {
      final merged = mergeRecentActivity(
        [_fellowship('f1', 'Morning')],
        [
          [
            _post(id: 'bad', createdAt: 'not-a-date'),
            _post(id: 'good', createdAt: '2020-01-01T00:00:00Z'),
          ]
        ],
        limit: 5,
      );
      expect(merged.map((e) => e.post.id), ['good', 'bad']);
    });

    test('tolerates fewer post lists than fellowships', () {
      final merged = mergeRecentActivity(
        [_fellowship('f1', 'Morning'), _fellowship('f2', 'Evening')],
        [
          [_post(id: 'a')]
        ],
        limit: 5,
      );
      expect(merged.length, 1);
    });

    test('keeps only the newest daily study per group', () {
      final merged = mergeRecentActivity(
        [_fellowship('f1', 'Morning'), _fellowship('f2', 'Evening')],
        [
          [
            _post(
                id: 'today',
                postType: 'daily',
                createdAt: '2026-09-06T08:00:00Z'),
            _post(
                id: 'yesterday',
                postType: 'daily',
                createdAt: '2026-09-05T08:00:00Z'),
            _post(id: 'member', createdAt: '2026-09-04T08:00:00Z'),
          ],
          [
            _post(
                id: 'other-today',
                fellowshipId: 'f2',
                postType: 'daily',
                createdAt: '2026-09-06T07:00:00Z'),
          ],
        ],
        limit: 5,
      );
      expect(merged.map((e) => e.post.id), ['today', 'other-today', 'member']);
    });

    test('returns an empty list when no group has posts', () {
      expect(
        mergeRecentActivity([_fellowship('f1', 'Morning')], [const []],
            limit: 5),
        isEmpty,
      );
    });
  });

  group('pickSuggestedFellowships', () {
    test('keeps only official groups, in discovery order', () {
      final picked = pickSuggestedFellowships([
        _public(id: '1', isOfficial: false, maxMembers: 12),
        _public(id: '2', maxMembers: 12),
        _public(id: '3', maxMembers: 12),
        _public(id: '4', maxMembers: 12),
      ]);
      expect(picked.map((f) => f.id), ['2', '3']);
    });

    test('skips groups that are already full', () {
      final picked = pickSuggestedFellowships([
        _public(id: '1', memberCount: 12, maxMembers: 12),
        _public(id: '2', memberCount: 11, maxMembers: 12),
      ]);
      expect(picked.map((f) => f.id), ['2']);
    });

    test('keeps unlimited groups regardless of member count', () {
      final picked = pickSuggestedFellowships([
        _public(id: '1', memberCount: 900),
      ]);
      expect(picked.map((f) => f.id), ['1']);
    });

    test('honours the limit and rejects non-positive limits', () {
      final all = [
        _public(id: '1'),
        _public(id: '2', maxMembers: 12),
        _public(id: '3')
      ];
      expect(pickSuggestedFellowships(all, limit: 1).length, 1);
      expect(pickSuggestedFellowships(all, limit: 0), isEmpty);
      expect(pickSuggestedFellowships(const []), isEmpty);
    });
  });
}
