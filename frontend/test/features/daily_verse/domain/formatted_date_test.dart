import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  final verse = DailyVerseEntity(
    id: 'v1',
    reference: 'John 3:16',
    referenceTranslations: const ReferenceTranslations(
        en: 'John 3:16', hi: 'यूहन्ना 3:16', ml: 'യോഹന്നാൻ 3:16'),
    translations:
        const DailyVerseTranslations(esv: 'a', hindi: 'b', malayalam: 'c'),
    date: DateTime(2026, 10, 6),
  );

  test('dates are localized', () {
    expect(verse.formattedDateFor('en'), 'October 6, 2026');
    expect(verse.formattedDateFor('hi'), '6 अक्तूबर 2026');
    expect(verse.formattedDateFor('ml'), 'ഒക്ടോബർ 6, 2026');
  });

  test('formattedDate stays English', () {
    expect(verse.formattedDate, 'October 6, 2026');
  });
}
