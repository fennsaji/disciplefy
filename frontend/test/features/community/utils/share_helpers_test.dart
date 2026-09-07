import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/utils/share_links.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/share_helpers.dart';

void main() {
  test('share text quotes 200 chars, author, fellowship and link', () {
    final p = FellowshipPostEntity(
      id: 'p1',
      fellowshipId: 'f1',
      authorUserId: 'u',
      content: 'x' * 300,
      postType: 'general',
      reactionCounts: const {},
      isDeleted: false,
      createdAt: 't',
      authorDisplayName: 'Rahul',
      commentCount: 0,
    );
    final t = buildPostShareText(
      post: p,
      fellowshipName: 'Disciplefy Fellowship',
      suffix: 'on Disciplefy',
    );
    expect(t.startsWith('"${'x' * 200}…"'), true);
    expect(t.contains('— Rahul in Disciplefy Fellowship on Disciplefy'), true);
    expect(t.trim().endsWith('/fellowship/f1/post/p1'), true);
    expect(t.contains(ShareLinks.publicWebUrl), true);
  });
}
