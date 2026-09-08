import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/utils/share_links.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/share_helpers.dart';

void main() {
  test('share text carries the whole post, author, fellowship and link', () {
    final p = FellowshipPostEntity(
      id: 'p1',
      fellowshipId: 'f1',
      authorUserId: 'u',
      content: '📖 The Nature and Wages of Sin\n'
          'What you are secretly ashamed of does not disqualify you.\n'
          '✝️ Romans 8:28\n'
          '💬 How does this passage speak to your current situation?',
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
    // The whole post travels: topic, body, scripture and question.
    expect(t.contains('📖 The Nature and Wages of Sin'), true);
    expect(t.contains('✝️ Romans 8:28'), true);
    expect(t.contains('💬 How does this passage speak'), true);
    expect(t.contains('…'), false);
    expect(t.contains('— Rahul in Disciplefy Fellowship on Disciplefy'), true);
    expect(t.trim().endsWith('/fellowship/f1/post/p1'), true);
    // Shared links go through the link host, not the web app: only that host
    // serves a preview card and an "open in the app" page.
    expect(t.contains(ShareLinks.shareOrigin), true);
    expect(t.contains(ShareLinks.publicWebUrl), false);
  });

  test('a pathological post is capped rather than sent whole', () {
    final p = FellowshipPostEntity(
      id: 'p2',
      fellowshipId: 'f1',
      authorUserId: 'u',
      content: 'x' * 6000,
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
    expect(t.contains('${'x' * 5000}…'), true);
    expect(t.contains('x' * 5001), false);
  });
}
