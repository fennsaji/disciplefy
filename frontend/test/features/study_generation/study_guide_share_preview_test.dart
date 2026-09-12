import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/study_guide_screen_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firstInterpretationParagraph', () {
    test('pulls a heading and its paragraph together, not just the heading',
        () {
      const interpretation = '**Creation Declares God\'s Existence**\n\n'
          'When you look at the night sky or hold a newborn baby, something '
          'inside you recognizes that this didn\'t happen by accident.\n\n'
          '**Design Points to a Designer**\n\n'
          'Have you ever marveled at how perfectly Earth is positioned?';

      final preview = firstInterpretationParagraph(interpretation);

      expect(preview, contains('Creation Declares God\'s Existence'));
      expect(preview, contains('something inside you recognizes'));
      // The second section must not leak into the preview — that defeats the
      // whole point of a short preview.
      expect(preview.contains('Design Points to a Designer'), false);
    });

    test('a plain first paragraph (no heading) is returned as-is', () {
      const interpretation = 'God is good, all the time.\n\n'
          'This is the second paragraph, which should not appear.';

      final preview = firstInterpretationParagraph(interpretation);

      expect(preview, 'God is good, all the time.');
    });

    test('a single-paragraph interpretation is returned whole', () {
      const interpretation = 'Just one paragraph here.';
      expect(firstInterpretationParagraph(interpretation), interpretation);
    });

    test('an empty interpretation does not throw', () {
      expect(firstInterpretationParagraph(''), '');
    });

    test('the real-world guide that prompted this fix stays short', () {
      // Regression: this exact interpretation (three long sections) used to
      // be dumped in full into the share text, which WhatsApp then cropped
      // mid-sentence. The preview must stay far shorter than the original.
      const interpretation = '''
**Creation Declares God's Existence**

When you look at the night sky or hold a newborn baby, something inside you recognizes that this didn't happen by accident. Paul writes that God's invisible qualities have been clearly seen since the creation of the world.

**Design Points to a Designer**

Have you ever marveled at how perfectly Earth is positioned in the solar system? This isn't luck — it's design.

**Conscience Reveals a Moral Lawgiver**

Why do you instinctively know that torturing children for fun is wrong?
''';

      final preview = firstInterpretationParagraph(interpretation);

      expect(preview.length, lessThanOrEqualTo(interpretation.length ~/ 2));
      expect(preview.contains('Conscience Reveals a Moral Lawgiver'), false);
    });
  });
}
