import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mentor_contact_helpers.dart';

void main() {
  group('normalizeWhatsAppDigits', () {
    test('strips +, -, (), and spaces', () {
      expect(normalizeWhatsAppDigits('+1 (415) 555-2671'), '14155552671');
    });

    test('leaves plain digits untouched', () {
      expect(normalizeWhatsAppDigits('919876543210'), '919876543210');
    });
  });

  group('buildWhatsAppUri', () {
    test('builds a wa.me link with the encoded prefilled text', () {
      final uri = buildWhatsAppUri(
        digits: '919876543210',
        text: 'Hi, I had a question.',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Hi, I had a question.');
    });
  });

  group('buildEmailUri', () {
    test('builds a mailto link with subject and body', () {
      final uri = buildEmailUri(
        address: 'mentor@example.com',
        subject: 'Question from my fellowship',
        body: 'Hi, I had a question.',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'mentor@example.com');
      expect(uri.queryParameters['subject'], 'Question from my fellowship');
      expect(uri.queryParameters['body'], 'Hi, I had a question.');
    });
  });

  group('substituteFellowshipName', () {
    test('replaces the {fellowship} placeholder', () {
      expect(
        substituteFellowshipName(
            "Hi, I'm from {fellowship} on Disciplefy.", 'Grace Group'),
        "Hi, I'm from Grace Group on Disciplefy.",
      );
    });
  });

  group('isValidWhatsAppValue', () {
    test('accepts 8-15 digit whatsapp numbers after stripping formatting', () {
      expect(isValidWhatsAppValue('+91 98765 43210'), true);
      expect(isValidWhatsAppValue('12345678'), true);
      expect(isValidWhatsAppValue('123456789012345'), true);
    });

    test('rejects whatsapp numbers that are too short or too long', () {
      expect(isValidWhatsAppValue('1234567'), false);
      expect(isValidWhatsAppValue('1234567890123456'), false);
    });

    test('rejects non-numeric whatsapp input', () {
      expect(isValidWhatsAppValue('abc12345678'), false);
    });

    test('rejects an empty value', () {
      expect(isValidWhatsAppValue(''), false);
    });
  });

  group('isValidEmailValue', () {
    test('accepts plausible email addresses', () {
      expect(isValidEmailValue('mentor@example.com'), true);
    });

    test('rejects malformed email addresses', () {
      expect(isValidEmailValue('not-an-email'), false);
      expect(isValidEmailValue('missing@domain'), false);
    });

    test('rejects an empty value', () {
      expect(isValidEmailValue(''), false);
    });
  });
}
