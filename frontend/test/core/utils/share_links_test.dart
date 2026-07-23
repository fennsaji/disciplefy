import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/utils/share_links.dart';

void main() {
  group('learningPath', () {
    test('points at the public web app, not a local origin', () {
      final url = ShareLinks.learningPath('abc123');
      // A shared link goes to other people — localhost would be useless.
      expect(url, startsWith('https://'));
      expect(url, isNot(contains('localhost')));
      expect(url, contains('/learning-path/abc123'));
    });

    test('path matches the declared route pattern', () {
      final url = ShareLinks.learningPath('abc123');
      final path = Uri.parse(url).path;
      // AppRoutes.learningPathDetail is '/learning-path/:pathId'.
      final pattern = RegExp(
        '^${AppRoutes.learningPathDetail.replaceFirst(':pathId', r'[^/]+')}\$',
      );
      expect(pattern.hasMatch(path), isTrue,
          reason: '$path must match ${AppRoutes.learningPathDetail}');
    });

    test('tags the open as coming from a share', () {
      final uri = Uri.parse(ShareLinks.learningPath('abc123'));
      expect(uri.queryParameters['source'], 'share');
    });

    test('honours an explicit source', () {
      final uri =
          Uri.parse(ShareLinks.learningPath('abc123', source: 'fellowship'));
      expect(uri.queryParameters['source'], 'fellowship');
    });

    test('escapes ids that would otherwise break the URL', () {
      final uri = Uri.parse(ShareLinks.learningPath('a b/c?d'));
      // The id must survive as a single path segment.
      final segments = uri.pathSegments;
      expect(segments.first, 'learning-path');
      expect(segments.length, 2);
      expect(Uri.decodeComponent(segments[1]), 'a b/c?d');
    });

    test('does not produce a double slash', () {
      expect(ShareLinks.learningPath('abc123'), isNot(contains('//learning')));
    });
  });

  group('learningPathMessage', () {
    test('includes the title and the link', () {
      final message = ShareLinks.learningPathMessage('Foundations', 'abc123');
      expect(message, contains('Foundations'));
      expect(message, contains(ShareLinks.learningPath('abc123')));
    });
  });
}
