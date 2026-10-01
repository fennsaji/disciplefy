import 'package:disciplefy_bible_study/shared/widgets/scripture_verse_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Object?> parse(String ref) {
    final p = ScriptureVerseSheet.parseReference(ref)!;
    return [p.book, p.chapter, p.verseStart, p.verseEnd, p.endChapter];
  }

  test('single verse', () {
    expect(parse('John 3:16'), ['John', 3, 16, null, null]);
  });

  test('same-chapter range', () {
    expect(parse('Matthew 5:1-12'), ['Matthew', 5, 1, 12, null]);
  });

  test('chapter only fetches whole chapter', () {
    expect(parse('भजन संहिता 23'), ['भजन संहिता', 23, 1, 999, null]);
  });

  test('cross-chapter range', () {
    expect(parse('1 Corinthians 10:23-11:1'), ['1 Corinthians', 10, 23, 1, 11]);
    expect(parse('1 कुरिन्थियों 10:23-11:1'), ['1 कुरिन्थियों', 10, 23, 1, 11]);
    expect(parse('1 കൊരിന്ത്യർ 10:23-11:1'), ['1 കൊരിന്ത്യർ', 10, 23, 1, 11]);
  });

  test('explicit same chapter end collapses to a range', () {
    expect(parse('John 3:16-3:18'), ['John', 3, 16, 18, null]);
  });

  test('end chapter before start is rejected', () {
    expect(ScriptureVerseSheet.parseReference('John 4:1-3:2'), isNull);
  });
}
