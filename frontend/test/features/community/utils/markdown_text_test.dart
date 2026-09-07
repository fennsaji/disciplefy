import 'package:disciplefy_bible_study/features/community/presentation/utils/markdown_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripEmphasisMarkers', () {
    test('removes bold markers', () {
      expect(
          stripEmphasisMarkers('this is **bold** text'), 'this is bold text');
    });

    test('removes asterisk italics', () {
      expect(
        stripEmphasisMarkers('Your job is *what you do*; Christ is *who you '
            'are*.'),
        'Your job is what you do; Christ is who you are.',
      );
    });

    test('removes underscore italics', () {
      expect(stripEmphasisMarkers('a _italic_ word'), 'a italic word');
      expect(stripEmphasisMarkers('_italic_'), 'italic');
    });

    test('leaves a lone asterisk alone', () {
      expect(stripEmphasisMarkers('5 * 3 = 15'), '5 * 3 = 15');
      expect(stripEmphasisMarkers('a stray * here'), 'a stray * here');
      expect(stripEmphasisMarkers('*'), '*');
    });

    test('leaves snake_case words alone', () {
      expect(stripEmphasisMarkers('call study_guide_id now'),
          'call study_guide_id now');
      expect(stripEmphasisMarkers('_leading and trailing_ word_here'),
          'leading and trailing word_here');
    });

    test('leaves unmatched markers alone', () {
      expect(stripEmphasisMarkers('an *unclosed emphasis'),
          'an *unclosed emphasis');
      expect(stripEmphasisMarkers('an _unclosed emphasis'),
          'an _unclosed emphasis');
    });

    test('does not join emphasis across lines', () {
      expect(stripEmphasisMarkers('one *line\nanother* line'),
          'one *line\nanother* line');
    });

    test('leaves plain text untouched', () {
      const plain = 'Peace be with you. A mentor may add more.';
      expect(stripEmphasisMarkers(plain), plain);
    });
  });
}
