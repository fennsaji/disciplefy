import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports only the people still tagged in the text', () {
    final tracker = MentionTracker()
      ..remember('@Fenn.Saji', 'user-1')
      ..remember('@Anna.T', 'user-2');

    expect(tracker.idsIn('@Fenn.Saji what do you think?'), ['user-1']);
    expect(
      tracker.idsIn('@Fenn.Saji and @Anna.T what do you think?'),
      containsAll(<String>['user-1', 'user-2']),
    );
  });

  test('a deleted mention un-tags the person', () {
    final tracker = MentionTracker()..remember('@Anna.T', 'user-2');

    expect(tracker.idsIn('never mind'), isEmpty);
  });

  test('the Discipler handle carries no account, so nobody is tagged', () {
    final tracker = MentionTracker()..remember('@Discipler', null);

    expect(tracker.idsIn('@Discipler is fasting required?'), isEmpty);
  });

  test('the same person tagged twice is reported once', () {
    final tracker = MentionTracker()..remember('@Fenn.Saji', 'user-1');

    expect(tracker.idsIn('@Fenn.Saji @Fenn.Saji hello'), ['user-1']);
  });

  test('clear forgets everything', () {
    final tracker = MentionTracker()..remember('@Fenn.Saji', 'user-1');
    tracker.clear();

    expect(tracker.idsIn('@Fenn.Saji hello'), isEmpty);
  });
}
