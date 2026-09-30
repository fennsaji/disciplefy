import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';

void main() {
  test('placeholder names count as unknown', () {
    expect(realMentorName(null), isNull);
    expect(realMentorName('  '), isNull);
    expect(realMentorName('Mentor'), isNull);
    expect(realMentorName('Unknown Member'), isNull);
  });

  test('real names are kept, trimmed', () {
    expect(realMentorName(' Anna George '), 'Anna George');
    expect(realMentorName('Mentor Joe'), 'Mentor Joe');
  });
}
