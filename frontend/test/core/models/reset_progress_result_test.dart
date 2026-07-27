import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResetProgressResult.fromJson', () {
    test('parses scope and integer counts', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'memory_verses',
        'counts': {
          'verses_deleted': 42,
          'collections_deleted': 2,
        },
      });

      expect(result.scope, 'memory_verses');
      expect(result.counts['verses_deleted'], 42);
      expect(result.counts['collections_deleted'], 2);
    });

    test('ignores non-integer count values such as booleans', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
        'counts': {
          'paths_reset': 3,
          'streak_reset': true,
        },
      });

      expect(result.counts['paths_reset'], 3);
      expect(result.counts.containsKey('streak_reset'), isFalse);
    });

    test('defaults to an empty counts map when counts is missing', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
      });

      expect(result.scope, 'learning_paths');
      expect(result.counts, isEmpty);
      expect(result.totalAffected, 0);
    });

    test('defaults scope to an empty string when absent', () {
      final result = ResetProgressResult.fromJson(const {});

      expect(result.scope, '');
    });

    test('totalAffected sums all integer counts', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
        'counts': {
          'paths_reset': 3,
          'topics_reset': 27,
          'achievements_reset': 5,
          'streak_reset': true,
        },
      });

      expect(result.totalAffected, 35);
    });

    test('equality is value-based', () {
      const json = {
        'scope': 'memory_verses',
        'counts': {'verses_deleted': 1},
      };

      expect(
        ResetProgressResult.fromJson(json),
        ResetProgressResult.fromJson(json),
      );
    });
  });
}
