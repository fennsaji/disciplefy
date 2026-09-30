import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/community/presentation/utils/guide_share_summary.dart';

void main() {
  test('keeps the first two sentences as plain text', () {
    expect(
      condenseGuideSummary(
          '**God works** all things together for good. For those who love '
          'Him — even the hard things. Paul then turns to *election*.'),
      'God works all things together for good. For those who love Him — '
      'even the hard things.',
    );
  });

  test('strips markdown links, headings and list markers', () {
    expect(
      condenseGuideSummary('## Summary\n- See [Romans 8](https://x.y) today.'),
      'Summary See Romans 8 today.',
    );
  });

  test('splits Hindi sentences on the danda', () {
    expect(
      condenseGuideSummary(
          'परमेश्वर भलाई करता है। वह प्रेम करता है। तीसरा वाक्य।'),
      'परमेश्वर भलाई करता है। वह प्रेम करता है।',
    );
  });

  test('caps long text on a word boundary with an ellipsis', () {
    final result = condenseGuideSummary('word ' * 200)!;
    expect(result.length, lessThanOrEqualTo(kSharedGuideSummaryMaxLength));
    expect(result.endsWith('…'), isTrue);
    expect(result.contains('  '), isFalse);
  });

  test('returns null for empty input', () {
    expect(condenseGuideSummary(null), isNull);
    expect(condenseGuideSummary('  **  '), isNull);
  });
}
