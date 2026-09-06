import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';

FellowshipPostEntity post(String author, {String type = 'general'}) =>
    FellowshipPostEntity(
        id: 'p',
        fellowshipId: 'f',
        authorUserId: author,
        content: 'c',
        postType: type,
        reactionCounts: const {},
        isDeleted: false,
        createdAt: 't',
        authorDisplayName: author,
        commentCount: 0);

void main() {
  test(
      'Discipler content: mentors and admins delete, nobody reports or blocks, everyone shares',
      () {
    expect(
        postMenuItems(post(kDisciplerUserId),
            isMentor: true, isAdmin: false, currentUserId: 'u'),
        ['share', 'delete']);
    expect(
        postMenuItems(post(kDisciplerUserId),
            isMentor: false, isAdmin: true, currentUserId: 'u'),
        ['share', 'delete']);
    expect(
        postMenuItems(post(kDisciplerUserId),
            isMentor: false, isAdmin: false, currentUserId: 'u'),
        ['share']);
  });
  test('member content keeps existing rules plus share', () {
    expect(
        postMenuItems(post('a'),
            isMentor: false, isAdmin: false, currentUserId: 'a'),
        ['share', 'delete']);
    expect(
        postMenuItems(post('a'),
            isMentor: false, isAdmin: false, currentUserId: 'b'),
        ['share', 'report', 'block']);
    expect(
        postMenuItems(post('a'),
            isMentor: true, isAdmin: false, currentUserId: 'b'),
        ['share', 'delete', 'block']);
  });
}
