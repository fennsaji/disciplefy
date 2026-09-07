import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';

void main() {
  test('replaces partial handle at cursor', () {
    final r = insertMention('Is fasting needed? @Disc', 24, '@Discipler');
    expect(r.text, 'Is fasting needed? @Discipler ');
    expect(r.cursor, r.text.length);
  });
  test('inserts at cursor when no partial', () {
    final r = insertMention('Hello world', 5, '@Anna');
    expect(r.text, 'Hello @Anna  world');
  });
  test('typing @ at end triggers', () {
    expect(shouldOpenMentionSheet('hello @', 7), true);
    expect(shouldOpenMentionSheet('a@b.com', 2), false);
  });
}
