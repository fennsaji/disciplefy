import 'package:disciplefy_bible_study/core/constants/bible_translation_citation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English cites BSB, Hindi/Malayalam cite IRV', () {
    expect(bibleTranslationAbbr('en'), 'BSB');
    expect(bibleTranslationAbbr('hi'), 'IRV');
    expect(bibleTranslationAbbr('ml-IN'), 'IRV');
    expect(bibleTranslationAbbr('ta'), '');
  });

  test('only the CC BY-SA IRV texts carry a licence notice', () {
    expect(bibleTranslationNotice('en'), isNull);
    expect(bibleTranslationNotice('hi'), contains('CC BY-SA 4.0'));
    expect(bibleTranslationNotice('ml'), contains('Bridge Connectivity'));
  });
}
