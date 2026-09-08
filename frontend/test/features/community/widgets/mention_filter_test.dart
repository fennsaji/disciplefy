import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/mention_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

MentionCandidate _c(String display, {bool discipler = false}) =>
    MentionCandidate(
      handle: '@${display.replaceAll(' ', '.')}',
      userId: discipler ? null : display,
      display: display,
      subtitle: discipler ? 'AI' : 'Member',
      isDiscipler: discipler,
    );

final _candidates = [
  _c('Discipler', discipler: true),
  _c('Fenn Ignatius Saji'),
  _c('Nandani Kumari'),
  _c('John Apple'),
  _c('Jerin Oommen'),
];

void main() {
  group('filterMentionCandidates', () {
    test('an empty query keeps everyone, Discipler first', () {
      final result = filterMentionCandidates(_candidates, '');

      expect(result.length, _candidates.length);
      expect(result.first.isDiscipler, isTrue);
    });

    test('matches a name fragment anywhere in the name', () {
      expect(
        filterMentionCandidates(_candidates, 'sa').map((c) => c.display),
        ['Fenn Ignatius Saji'],
      );
    });

    test('is case-insensitive', () {
      expect(
        filterMentionCandidates(_candidates, 'NANDANI').map((c) => c.display),
        ['Nandani Kumari'],
      );
    });

    test('ignores the @ and the dots that stand in for spaces', () {
      expect(
        filterMentionCandidates(_candidates, '@Fenn.Ig').map((c) => c.display),
        ['Fenn Ignatius Saji'],
      );
    });

    test('matching several people keeps them all', () {
      expect(
        filterMentionCandidates(_candidates, 'j').map((c) => c.display),
        containsAll(
            <String>['Fenn Ignatius Saji', 'John Apple', 'Jerin Oommen']),
      );
    });

    test('no match returns empty rather than everyone', () {
      expect(filterMentionCandidates(_candidates, 'zzz'), isEmpty);
    });
  });

  group('mentionQueryAt', () {
    test('returns what has been typed after the @', () {
      expect(mentionQueryAt('hey @sa', 7), 'sa');
    });

    test('is empty right after the @ itself', () {
      expect(mentionQueryAt('hey @', 5), '');
    });

    test('is empty when the cursor is not in a mention', () {
      expect(mentionQueryAt('hey there', 9), '');
      expect(mentionQueryAt('a@b', 3), '');
    });

    test('stops at the space before the mention', () {
      expect(mentionQueryAt('@Fenn.Sa', 8), 'Fenn.Sa');
    });
  });
}
