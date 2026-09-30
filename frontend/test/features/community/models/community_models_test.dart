import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/features/community/data/models/discipler_activity_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_comment_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_post_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/public_fellowship_model.dart';

void main() {
  test('post model reads Discipler fields and derives authorIsSystem', () {
    final p = FellowshipPostModel.fromJson({
      'id': 'p',
      'fellowship_id': 'f',
      'author_user_id': kDisciplerUserId,
      'content': 'x',
      'post_type': 'daily',
      'reaction_counts': {'amen': 2},
      'is_deleted': false,
      'created_at': '2026-09-06T01:00:00Z',
      'author_display_name': 'Discipler',
      'comment_count': 0,
      'mentions_discipler': false,
    }).toEntity();
    expect(p.authorIsSystem, true);
    expect(p.isDaily, true);
  });

  test('post model defaults the new booleans when absent', () {
    final p = FellowshipPostModel.fromJson({
      'id': 'p',
      'fellowship_id': 'f',
      'author_user_id': 'u',
      'content': 'x',
      'post_type': 'general',
      'reaction_counts': {},
      'is_deleted': false,
      'created_at': 'c',
      'author_display_name': 'n',
      'comment_count': 1,
    }).toEntity();
    expect(p.mentionsDiscipler, false);
    expect(p.authorIsSystem, false);
    // Older posts carry no study mode or summary.
    expect(p.guideStudyMode, isNull);
    expect(p.guideSummary, isNull);
  });

  test('post model reads the shared guide study mode and summary', () {
    final p = FellowshipPostModel.fromJson({
      'id': 'p',
      'fellowship_id': 'f',
      'author_user_id': 'u',
      'content': '',
      'post_type': 'shared_guide',
      'reaction_counts': {},
      'is_deleted': false,
      'created_at': '2026-09-06T01:00:00Z',
      'author_display_name': 'n',
      'comment_count': 0,
      'study_guide_id': 'g1',
      'guide_title': 'Romans 8:28',
      'guide_input_type': 'scripture',
      'guide_language': 'en',
      'guide_study_mode': 'standard',
      'guide_summary': 'God works all things together for good.',
    }).toEntity();
    expect(p.guideStudyMode, 'standard');
    expect(p.guideSummary, 'God works all things together for good.');
    // Survives the reaction-toggle copy.
    final copy = p.copyWith(reactionCounts: const {'fire': 1});
    expect(copy.guideStudyMode, 'standard');
    expect(copy.guideSummary, 'God works all things together for good.');
  });

  test('comment model reads pending, mention and guide fields', () {
    final c = FellowshipCommentModel.fromJson({
      'id': 'c',
      'post_id': 'p',
      'author_user_id': kDisciplerUserId,
      'content': 'x',
      'is_deleted': false,
      'created_at': 'c',
      'author_display_name': 'Discipler',
      'is_pending_review': true,
      'mentions_discipler': false,
      'study_guide_id': null,
      'guide_title': 'Prayer',
      'guide_input_type': 'topic',
      'guide_input_value': 'prayer',
      'guide_language': 'hi',
    }).toEntity();
    expect(c.isPendingReview, true);
    expect(c.authorIsSystem, true);
    expect(c.hasGuide, true);
    expect(c.studyGuideId, null);
  });

  test('public fellowship keeps null max_members as unlimited', () {
    final f = PublicFellowshipModel.fromJson({
      'id': 'f',
      'name': 'n',
      'language': 'en',
      'member_count': 40,
      'max_members': null,
      'is_official': true,
    }).toEntity();
    expect(f.maxMembers, null);
    expect(f.isUnlimited, true);
    expect(f.isOfficial, true);
  });

  test('fellowship model reads mentors and prefs', () {
    final f = FellowshipModel.fromJson({
      'id': 'f',
      'name': 'n',
      'member_count': 3,
      'user_role': 'mentor',
      'joined_at': 'j',
      'created_at': 'c',
      'mentors': [
        {'user_id': 'a', 'display_name': 'Anna', 'avatar_url': null}
      ],
      'is_official': true,
      'discipler_allowed': true,
      'daily_post_allowed': false,
      'discipler_reply_mode': 'review',
      'discipler_reply_scope': 'lessons_only',
      'discipler_reply_delay_min': 30,
      'discipler_react_enabled': false,
      'daily_post_on': true,
      'daily_post_frequency_days': 2,
      'daily_post_auto_advance': false,
      'my_discipler_activity_push': false,
    }).toEntity();
    expect(f.mentors.single.displayName, 'Anna');
    expect(f.disciplerReplyMode, 'review');
    expect(f.disciplerReplyDelayMin, 30);
    expect(f.myDisciplerActivityPush, false);
    expect(f.dailyPostFrequencyDays, 2);
    expect(f.dailyPostAutoAdvance, false);
  });

  test('fellowship model defaults daily post prefs when absent', () {
    final f = FellowshipModel.fromJson({
      'id': 'f',
      'name': 'n',
      'member_count': 1,
      'user_role': 'member',
      'joined_at': 'j',
      'created_at': 'c',
    }).toEntity();
    expect(f.dailyPostFrequencyDays, 1);
    expect(f.dailyPostAutoAdvance, true);
  });

  test('activity model joins post and comment', () {
    final a = DisciplerActivityModel.fromJson({
      'id': 'a',
      'kind': 'draft',
      'post_id': 'p',
      'comment_id': 'c',
      'reaction': null,
      'language': 'en',
      'summary': 's',
      'reviewed_at': null,
      'created_at': 't',
      'post': {'content': 'q?', 'post_type': 'question', 'topic_title': null},
      'comment': {
        'content': 'ans',
        'is_pending_review': true,
        'is_deleted': false
      },
    }).toEntity();
    expect(a.commentPending, true);
    expect(a.postContent, 'q?');
  });
}
