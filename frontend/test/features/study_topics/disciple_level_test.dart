import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/disciple_level.dart';

/// The fellowship path picker flattens a category listing, which dropped the
/// category headings and left a list that read as random: seeker, follower,
/// disciple, seeker. It now sorts by the discipleship progression instead, and
/// these pin the order that sort depends on.
void main() {
  group('discipleLevelRank', () {
    test('orders the progression, not the alphabet', () {
      final levels = ['disciple', 'seeker', 'leader', 'follower']..sort(
          (a, b) => discipleLevelRank(a).compareTo(discipleLevelRank(b)),
        );

      expect(levels, ['seeker', 'follower', 'disciple', 'leader']);
    });

    test('believer ranks with follower, the level it is a synonym of', () {
      expect(discipleLevelRank('believer'), discipleLevelRank('follower'));
    });

    test('is case and whitespace insensitive', () {
      expect(discipleLevelRank('  SEEKER '), discipleLevelRank('seeker'));
      expect(discipleLevelRank('Disciple'), discipleLevelRank('disciple'));
    });

    test('an unknown level sorts last, never first', () {
      // A level this build has not been taught about must not present itself as
      // the beginner's starting point at the top of the picker.
      final unknown = discipleLevelRank('archbishop');
      expect(unknown, greaterThan(discipleLevelRank('leader')));

      for (final level in [null, '', '   ']) {
        expect(
            discipleLevelRank(level), greaterThan(discipleLevelRank('leader')));
      }
    });

    test('sorting is stable, so ordering within a level is preserved', () {
      // The listing carries personalisation and fellowship progress inside each
      // level; sorting must not scramble it.
      final paths = [
        ('b', 'disciple'),
        ('a', 'seeker'),
        ('c', 'disciple'),
        ('d', 'seeker'),
      ];
      final sorted = [...paths]..sort(
          (x, y) => discipleLevelRank(x.$2).compareTo(discipleLevelRank(y.$2)),
        );

      expect(sorted.map((e) => e.$1).toList(), ['a', 'd', 'b', 'c']);
    });
  });

  group('discipleLevelLabelKey', () {
    test('every level in the progression has a translation key', () {
      for (final level in discipleLevelOrder) {
        expect(discipleLevelLabelKey(level), isNotNull,
            reason: 'no key for $level');
      }
      expect(discipleLevelLabelKey('believer'),
          TranslationKeys.discipleLevelBeliever);
    });

    test('an unrecognised level has no key, so callers show it as-is', () {
      expect(discipleLevelLabelKey('archbishop'), isNull);
      expect(discipleLevelLabelKey(null), isNull);
    });
  });
}
