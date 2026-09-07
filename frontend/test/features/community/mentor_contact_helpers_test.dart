import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mentor_contact_helpers.dart';

void main() {
  group('buildEmailUri', () {
    test('percent-encodes spaces instead of form-encoding them as "+"', () {
      final uri = buildEmailUri(
        address: 'fenn@disciplefy.in',
        subject: 'Question from my fellowship',
        body: "Hi, I'm from Just Us on Disciplefy and I had a question.",
      );

      expect(uri.toString(), isNot(contains('+')));
      expect(uri.query, contains('subject=Question%20from%20my%20fellowship'));
      expect(uri.queryParameters['subject'], 'Question from my fellowship');
      expect(
        uri.queryParameters['body'],
        "Hi, I'm from Just Us on Disciplefy and I had a question.",
      );
    });

    test('keeps the address in the path, not the query', () {
      final uri = buildEmailUri(
        address: 'mentor@example.com',
        subject: 'Hi there',
        body: 'Body text',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'mentor@example.com');
    });
  });

  group('buildWhatsAppUri', () {
    test('percent-encodes the prefilled text', () {
      final uri = buildWhatsAppUri(
        digits: '919876543210',
        text: 'Question from my fellowship',
      );

      expect(uri.toString(), isNot(contains('+')));
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Question from my fellowship');
    });
  });

  group('substituteFellowshipName', () {
    test('replaces the {fellowship} placeholder', () {
      expect(
        substituteFellowshipName('Hi, I am from {fellowship}.', 'Just Us'),
        'Hi, I am from Just Us.',
      );
    });
  });
}
