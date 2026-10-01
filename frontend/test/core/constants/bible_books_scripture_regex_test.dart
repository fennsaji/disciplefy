import 'package:disciplefy_bible_study/core/constants/bible_books.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final regex = BibleBooks.createScriptureRegex();

  RegExpMatch match(String text) => regex.firstMatch(text)!;

  test('single verse', () {
    final m = match('Read John 3:16 today');
    expect(m.group(0), 'John 3:16');
    expect([m.group(2), m.group(3), m.group(4), m.group(5)],
        ['3', '16', null, null]);
  });

  test('same-chapter range keeps group 4 as end verse', () {
    final m = match('Matthew 5:1-12.');
    expect(m.group(0), 'Matthew 5:1-12');
    expect([m.group(3), m.group(4), m.group(5), m.group(6)],
        ['1', '12', null, null]);
  });

  test('cross-chapter range matches whole reference', () {
    final m = match('Passage: 1 Corinthians 10:23-11:1');
    expect(m.group(0), '1 Corinthians 10:23-11:1');
    expect(m.group(1), '1 Corinthians');
    expect([m.group(2), m.group(3), m.group(4), m.group(5), m.group(6)],
        ['10', '23', null, '11', '1']);
  });

  test('range followed by a colon and text stays a same-chapter range', () {
    final m = match('John 3:16-17: love');
    expect(m.group(0), 'John 3:16-17');
    expect(m.group(4), '17');
  });

  test('chapter only', () {
    final m = match('Psalms 23 is beloved');
    expect(m.group(0), 'Psalms 23');
    expect(m.group(3), isNull);
  });

  test('Hindi cross-chapter', () {
    final m = match('पढ़ें 1 कुरिन्थियों 10:23-11:1 ।');
    expect(m.group(0), '1 कुरिन्थियों 10:23-11:1');
    expect([m.group(5), m.group(6)], ['11', '1']);
  });

  test('Malayalam cross-chapter and single verse', () {
    expect(
        match('1 കൊരിന്ത്യർ 10:23-11:1').group(0), '1 കൊരിന്ത്യർ 10:23-11:1');
    expect(match('യോഹന്നാൻ 3:16').group(0), 'യോഹന്നാൻ 3:16');
  });
}
