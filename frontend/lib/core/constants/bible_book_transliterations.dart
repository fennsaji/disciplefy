// Bible book romanization data for Hinglish and Manglish input support.
//
// Each entry maps a lowercase romanized spelling to the canonical English
// book name (used for API calls) and the local-script display name (shown
// on suggestion chips).

class BibleBookRomanEntry {
  final String romanized; // lowercase romanized form to prefix-match against
  final String english; // canonical English book name to insert into field
  final String localDisplay; // local-script name to show on chip
  final String language; // 'hi' or 'ml'

  const BibleBookRomanEntry({
    required this.romanized,
    required this.english,
    required this.localDisplay,
    required this.language,
  });
}

/// Provides prefix-searchable romanized spellings for Hindi and Malayalam
/// Bible book names (Hinglish and Manglish respectively).
class BibleBookTransliterations {
  BibleBookTransliterations._();

  /// All entries sorted by romanized form for consistent ordering.
  static const List<BibleBookRomanEntry> _all = [
    // ──────────────────────────── HINDI (Hinglish) ───────────────────────────

    // Old Testament
    BibleBookRomanEntry(
        romanized: 'utpatti',
        english: 'Genesis',
        localDisplay: 'उत्पत्ति',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'utpati',
        english: 'Genesis',
        localDisplay: 'उत्पत्ति',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nirgaman',
        english: 'Exodus',
        localDisplay: 'निर्गमन',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nirgman',
        english: 'Exodus',
        localDisplay: 'निर्गमन',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'levyvyavastha',
        english: 'Leviticus',
        localDisplay: 'लैव्यव्यवस्था',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'levyi',
        english: 'Leviticus',
        localDisplay: 'लैव्यव्यवस्था',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ginti',
        english: 'Numbers',
        localDisplay: 'गिनती',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'vyavastha',
        english: 'Deuteronomy',
        localDisplay: 'व्यवस्थाविवरण',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yahoshu',
        english: 'Joshua',
        localDisplay: 'यहोशू',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yehoshu',
        english: 'Joshua',
        localDisplay: 'यहोशू',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nyayiyon',
        english: 'Judges',
        localDisplay: 'न्यायियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nyayi',
        english: 'Judges',
        localDisplay: 'न्यायियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'root',
        english: 'Ruth',
        localDisplay: 'रूत',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'rut', english: 'Ruth', localDisplay: 'रूत', language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 shamuil',
        english: '1 Samuel',
        localDisplay: '1 शमूएल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 shamuil',
        english: '2 Samuel',
        localDisplay: '2 शमूएल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 shamu',
        english: '1 Samuel',
        localDisplay: '1 शमूएल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 shamu',
        english: '2 Samuel',
        localDisplay: '2 शमूएल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 rajaon',
        english: '1 Kings',
        localDisplay: '1 राजाओं',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 rajaon',
        english: '2 Kings',
        localDisplay: '2 राजाओं',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 raja',
        english: '1 Kings',
        localDisplay: '1 राजाओं',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 raja',
        english: '2 Kings',
        localDisplay: '2 राजाओं',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 itihas',
        english: '1 Chronicles',
        localDisplay: '1 इतिहास',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 itihas',
        english: '2 Chronicles',
        localDisplay: '2 इतिहास',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ejra',
        english: 'Ezra',
        localDisplay: 'एज्रा',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nehemyah',
        english: 'Nehemiah',
        localDisplay: 'नहेम्याह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nehemia',
        english: 'Nehemiah',
        localDisplay: 'नहेम्याह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ester',
        english: 'Esther',
        localDisplay: 'एस्तेर',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ayyub',
        english: 'Job',
        localDisplay: 'अय्यूब',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ayub',
        english: 'Job',
        localDisplay: 'अय्यूब',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'bhajan',
        english: 'Psalms',
        localDisplay: 'भजन संहिता',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'bhajansamhita',
        english: 'Psalms',
        localDisplay: 'भजन संहिता',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nitivachan',
        english: 'Proverbs',
        localDisplay: 'नीतिवचन',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'neeti',
        english: 'Proverbs',
        localDisplay: 'नीतिवचन',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'sabhopdesak',
        english: 'Ecclesiastes',
        localDisplay: 'सभोपदेशक',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'sabho',
        english: 'Ecclesiastes',
        localDisplay: 'सभोपदेशक',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'shreshtha',
        english: 'Song of Solomon',
        localDisplay: 'श्रेष्ठगीत',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yashayah',
        english: 'Isaiah',
        localDisplay: 'यशायाह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yashaya',
        english: 'Isaiah',
        localDisplay: 'यशायाह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yirmayah',
        english: 'Jeremiah',
        localDisplay: 'यिर्मयाह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yirmya',
        english: 'Jeremiah',
        localDisplay: 'यिर्मयाह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'vilapgeet',
        english: 'Lamentations',
        localDisplay: 'विलापगीत',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'vilap',
        english: 'Lamentations',
        localDisplay: 'विलापगीत',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yahejkel',
        english: 'Ezekiel',
        localDisplay: 'यहेजकेल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'daniyal',
        english: 'Daniel',
        localDisplay: 'दानिय्येल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'hoshe',
        english: 'Hosea',
        localDisplay: 'होशे',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yoel',
        english: 'Joel',
        localDisplay: 'योएल',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'aaamos',
        english: 'Amos',
        localDisplay: 'आमोस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'obadyah',
        english: 'Obadiah',
        localDisplay: 'ओबद्याह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yona',
        english: 'Jonah',
        localDisplay: 'योना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'mika',
        english: 'Micah',
        localDisplay: 'मीका',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'nahum',
        english: 'Nahum',
        localDisplay: 'नहूम',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'habakkuk',
        english: 'Habakkuk',
        localDisplay: 'हबक्कूक',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'sapanyah',
        english: 'Zephaniah',
        localDisplay: 'सपन्याह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'haggai',
        english: 'Haggai',
        localDisplay: 'हाग्गै',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'jakaryah',
        english: 'Zechariah',
        localDisplay: 'जकर्याह',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'malaki',
        english: 'Malachi',
        localDisplay: 'मलाकी',
        language: 'hi'),

    // New Testament (Hindi)
    BibleBookRomanEntry(
        romanized: 'matti',
        english: 'Matthew',
        localDisplay: 'मत्ती',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'matthi',
        english: 'Matthew',
        localDisplay: 'मत्ती',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'mati',
        english: 'Matthew',
        localDisplay: 'मत्ती',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'markus',
        english: 'Mark',
        localDisplay: 'मरकुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'marcus',
        english: 'Mark',
        localDisplay: 'मरकुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'luka',
        english: 'Luke',
        localDisplay: 'लूका',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yuhanna',
        english: 'John',
        localDisplay: 'यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yohanna',
        english: 'John',
        localDisplay: 'यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'preriton',
        english: 'Acts',
        localDisplay: 'प्रेरितों के काम',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'romiyon',
        english: 'Romans',
        localDisplay: 'रोमियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'romio',
        english: 'Romans',
        localDisplay: 'रोमियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 korinthi',
        english: '1 Corinthians',
        localDisplay: '1 कुरिन्थियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 korinthi',
        english: '2 Corinthians',
        localDisplay: '2 कुरिन्थियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 kuri',
        english: '1 Corinthians',
        localDisplay: '1 कुरिन्थियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 kuri',
        english: '2 Corinthians',
        localDisplay: '2 कुरिन्थियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'galatiyon',
        english: 'Galatians',
        localDisplay: 'गलातियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'galati',
        english: 'Galatians',
        localDisplay: 'गलातियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ifisiyon',
        english: 'Ephesians',
        localDisplay: 'इफिसियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ifisi',
        english: 'Ephesians',
        localDisplay: 'इफिसियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'filippiyon',
        english: 'Philippians',
        localDisplay: 'फिलिप्पियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'kulussyon',
        english: 'Colossians',
        localDisplay: 'कुलुस्सियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 thissaluni',
        english: '1 Thessalonians',
        localDisplay: '1 थिस्सलुनीकियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 thissaluni',
        english: '2 Thessalonians',
        localDisplay: '2 थिस्सलुनीकियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 thissa',
        english: '1 Thessalonians',
        localDisplay: '1 थिस्सलुनीकियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 thissa',
        english: '2 Thessalonians',
        localDisplay: '2 थिस्सलुनीकियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 timothy',
        english: '1 Timothy',
        localDisplay: '1 तीमुथियुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 timothy',
        english: '2 Timothy',
        localDisplay: '2 तीमुथियुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 tiimuthi',
        english: '1 Timothy',
        localDisplay: '1 तीमुथियुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 tiimuthi',
        english: '2 Timothy',
        localDisplay: '2 तीमुथियुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'titus',
        english: 'Titus',
        localDisplay: 'तीतुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'teetus',
        english: 'Titus',
        localDisplay: 'तीतुस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'filemon',
        english: 'Philemon',
        localDisplay: 'फिलेमोन',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ibraniyon',
        english: 'Hebrews',
        localDisplay: 'इब्रानियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'ibrani',
        english: 'Hebrews',
        localDisplay: 'इब्रानियों',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yakub',
        english: 'James',
        localDisplay: 'याकूब',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yakoob',
        english: 'James',
        localDisplay: 'याकूब',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 patras',
        english: '1 Peter',
        localDisplay: '1 पतरस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 patras',
        english: '2 Peter',
        localDisplay: '2 पतरस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 petrus',
        english: '1 Peter',
        localDisplay: '1 पतरस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 petrus',
        english: '2 Peter',
        localDisplay: '2 पतरस',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 yuhanna',
        english: '1 John',
        localDisplay: '1 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 yuhanna',
        english: '2 John',
        localDisplay: '2 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '3 yuhanna',
        english: '3 John',
        localDisplay: '3 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '1 yohanna',
        english: '1 John',
        localDisplay: '1 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '2 yohanna',
        english: '2 John',
        localDisplay: '2 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: '3 yohanna',
        english: '3 John',
        localDisplay: '3 यूहन्ना',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yahuda',
        english: 'Jude',
        localDisplay: 'यहूदा',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'yehuda',
        english: 'Jude',
        localDisplay: 'यहूदा',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'prakashit',
        english: 'Revelation',
        localDisplay: 'प्रकाशितवाक्य',
        language: 'hi'),
    BibleBookRomanEntry(
        romanized: 'prakashitvakya',
        english: 'Revelation',
        localDisplay: 'प्रकाशितवाक्य',
        language: 'hi'),

    // ────────────────────────── MALAYALAM (Manglish) ─────────────────────────

    // Old Testament
    BibleBookRomanEntry(
        romanized: 'ulpa',
        english: 'Genesis',
        localDisplay: 'ഉല്പ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'uthpathi',
        english: 'Genesis',
        localDisplay: 'ഉല്പ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'pura',
        english: 'Exodus',
        localDisplay: 'പുറ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'purappadu',
        english: 'Exodus',
        localDisplay: 'പുറ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'levya',
        english: 'Leviticus',
        localDisplay: 'ലേവ്യ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sankhya',
        english: 'Numbers',
        localDisplay: 'സംഖ്യ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'avar',
        english: 'Deuteronomy',
        localDisplay: 'ആവർ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'avarthanam',
        english: 'Deuteronomy',
        localDisplay: 'ആവർ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yoshuva',
        english: 'Joshua',
        localDisplay: 'യോശുവ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'nyaya',
        english: 'Judges',
        localDisplay: 'ന്യായാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'nyayadhipan',
        english: 'Judges',
        localDisplay: 'ന്യായാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 shamu',
        english: '1 Samuel',
        localDisplay: '1 ശമു.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 shamu',
        english: '2 Samuel',
        localDisplay: '2 ശമു.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 shamuvel',
        english: '1 Samuel',
        localDisplay: '1 ശമു.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 shamuvel',
        english: '2 Samuel',
        localDisplay: '2 ശമു.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 raja',
        english: '1 Kings',
        localDisplay: '1 രാജാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 raja',
        english: '2 Kings',
        localDisplay: '2 രാജാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 rajakkan',
        english: '1 Kings',
        localDisplay: '1 രാജാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 rajakkan',
        english: '2 Kings',
        localDisplay: '2 രാജാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 dina',
        english: '1 Chronicles',
        localDisplay: '1 ദിന.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 dina',
        english: '2 Chronicles',
        localDisplay: '2 ദിന.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'esra',
        english: 'Ezra',
        localDisplay: 'എസ്രാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'nehe',
        english: 'Nehemiah',
        localDisplay: 'നെഹെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'nehemyav',
        english: 'Nehemiah',
        localDisplay: 'നെഹെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'esthe',
        english: 'Esther',
        localDisplay: 'എസ്ഥേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'estheer',
        english: 'Esther',
        localDisplay: 'എസ്ഥേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'iyyo',
        english: 'Job',
        localDisplay: 'ഇയ്യോ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'iyyob',
        english: 'Job',
        localDisplay: 'ഇയ്യോ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sanki',
        english: 'Psalms',
        localDisplay: 'സങ്കീ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sankeerthanam',
        english: 'Psalms',
        localDisplay: 'സങ്കീ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sadru',
        english: 'Proverbs',
        localDisplay: 'സദൃ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sadrushavakhyam',
        english: 'Proverbs',
        localDisplay: 'സദൃ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sabha',
        english: 'Ecclesiastes',
        localDisplay: 'സഭാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sabhaprasangi',
        english: 'Ecclesiastes',
        localDisplay: 'സഭാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'uttha',
        english: 'Song of Solomon',
        localDisplay: 'ഉത്ത.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'uttamageetham',
        english: 'Song of Solomon',
        localDisplay: 'ഉത്ത.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yesha',
        english: 'Isaiah',
        localDisplay: 'യെശ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yeshayya',
        english: 'Isaiah',
        localDisplay: 'യെശ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yire',
        english: 'Jeremiah',
        localDisplay: 'യിരെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yiremyav',
        english: 'Jeremiah',
        localDisplay: 'യിരെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'vila',
        english: 'Lamentations',
        localDisplay: 'വിലാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'vilapangal',
        english: 'Lamentations',
        localDisplay: 'വിലാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yehe',
        english: 'Ezekiel',
        localDisplay: 'യെഹെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yehezkel',
        english: 'Ezekiel',
        localDisplay: 'യെഹെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'dani',
        english: 'Daniel',
        localDisplay: 'ദാനീ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'hoshe',
        english: 'Hosea',
        localDisplay: 'ഹോശേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'hoshea',
        english: 'Hosea',
        localDisplay: 'ഹോശേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yove',
        english: 'Joel',
        localDisplay: 'യോവേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yovel',
        english: 'Joel',
        localDisplay: 'യോവേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'amo',
        english: 'Amos',
        localDisplay: 'ആമോ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'ob',
        english: 'Obadiah',
        localDisplay: 'ഓബ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'obad',
        english: 'Obadiah',
        localDisplay: 'ഓബ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yona',
        english: 'Jonah',
        localDisplay: 'യോനാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'mekha',
        english: 'Micah',
        localDisplay: 'മീഖാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'mikha',
        english: 'Micah',
        localDisplay: 'മീഖാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'haba',
        english: 'Habakkuk',
        localDisplay: 'ഹബ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sepha',
        english: 'Zephaniah',
        localDisplay: 'സെഫ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sephanya',
        english: 'Zephaniah',
        localDisplay: 'സെഫ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'hagga',
        english: 'Haggai',
        localDisplay: 'ഹഗ്ഗാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sekha',
        english: 'Zechariah',
        localDisplay: 'സെഖ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'sekharya',
        english: 'Zechariah',
        localDisplay: 'സെഖ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'malakhi',
        english: 'Malachi',
        localDisplay: 'മലാ.',
        language: 'ml'),

    // New Testament (Malayalam)
    BibleBookRomanEntry(
        romanized: 'matta',
        english: 'Matthew',
        localDisplay: 'മത്താ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'mattha',
        english: 'Matthew',
        localDisplay: 'മത്താ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'mattai',
        english: 'Matthew',
        localDisplay: 'മത്താ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'markko',
        english: 'Mark',
        localDisplay: 'മർക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'marko',
        english: 'Mark',
        localDisplay: 'മർക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'markos',
        english: 'Mark',
        localDisplay: 'മർക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'lukko',
        english: 'Luke',
        localDisplay: 'ലൂക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'luko',
        english: 'Luke',
        localDisplay: 'ലൂക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'lukkos',
        english: 'Luke',
        localDisplay: 'ലൂക്കൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yoha',
        english: 'John',
        localDisplay: 'യോഹ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yohannan',
        english: 'John',
        localDisplay: 'യോഹ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'pravruthi',
        english: 'Acts',
        localDisplay: 'പ്രവൃത്തികൾ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'pravrutti',
        english: 'Acts',
        localDisplay: 'പ്രവൃത്തികൾ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'roma',
        english: 'Romans',
        localDisplay: 'റോമ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'romakkar',
        english: 'Romans',
        localDisplay: 'റോമ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 kori',
        english: '1 Corinthians',
        localDisplay: '1 കൊരി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 kori',
        english: '2 Corinthians',
        localDisplay: '2 കൊരി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 korinthi',
        english: '1 Corinthians',
        localDisplay: '1 കൊരി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 korinthi',
        english: '2 Corinthians',
        localDisplay: '2 കൊരി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'gala',
        english: 'Galatians',
        localDisplay: 'ഗലാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'galathyar',
        english: 'Galatians',
        localDisplay: 'ഗലാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'ephe',
        english: 'Ephesians',
        localDisplay: 'എഫെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'ephesyar',
        english: 'Ephesians',
        localDisplay: 'എഫെ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'phili',
        english: 'Philippians',
        localDisplay: 'ഫിലി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'fili',
        english: 'Philippians',
        localDisplay: 'ഫിലി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'kolo',
        english: 'Colossians',
        localDisplay: 'കൊലൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 thessa',
        english: '1 Thessalonians',
        localDisplay: '1 തെസ്സ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 thessa',
        english: '2 Thessalonians',
        localDisplay: '2 തെസ്സ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 thimo',
        english: '1 Timothy',
        localDisplay: '1 തിമൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 thimo',
        english: '2 Timothy',
        localDisplay: '2 തിമൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 timotheyos',
        english: '1 Timothy',
        localDisplay: '1 തിമൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 timotheyos',
        english: '2 Timothy',
        localDisplay: '2 തിമൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'teetho',
        english: 'Titus',
        localDisplay: 'തീത്തൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'phile',
        english: 'Philemon',
        localDisplay: 'ഫിലേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'file',
        english: 'Philemon',
        localDisplay: 'ഫിലേ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'ebra',
        english: 'Hebrews',
        localDisplay: 'എബ്രാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'ebraayar',
        english: 'Hebrews',
        localDisplay: 'എബ്രാ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yakko',
        english: 'James',
        localDisplay: 'യാക്കോ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 pathro',
        english: '1 Peter',
        localDisplay: '1 പത്രൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 pathro',
        english: '2 Peter',
        localDisplay: '2 പത്രൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 patros',
        english: '1 Peter',
        localDisplay: '1 പത്രൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 patros',
        english: '2 Peter',
        localDisplay: '2 പത്രൊ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '1 yoha',
        english: '1 John',
        localDisplay: '1 യോഹ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '2 yoha',
        english: '2 John',
        localDisplay: '2 യോഹ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: '3 yoha',
        english: '3 John',
        localDisplay: '3 യോഹ.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yuda',
        english: 'Jude',
        localDisplay: 'യൂദാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'yudha',
        english: 'Jude',
        localDisplay: 'യൂദാ',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'veli',
        english: 'Revelation',
        localDisplay: 'വെളി.',
        language: 'ml'),
    BibleBookRomanEntry(
        romanized: 'velippadu',
        english: 'Revelation',
        localDisplay: 'വെളി.',
        language: 'ml'),
  ];

  /// Search Hindi romanizations (Hinglish) by prefix.
  static List<BibleBookRomanEntry> searchHindi(String query) =>
      _searchByLanguage(query, 'hi');

  /// Search Malayalam romanizations (Manglish) by prefix.
  static List<BibleBookRomanEntry> searchMalayalam(String query) =>
      _searchByLanguage(query, 'ml');

  static List<BibleBookRomanEntry> _searchByLanguage(
      String query, String language) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final seen = <String>{};
    final results = <BibleBookRomanEntry>[];
    for (final entry in _all) {
      if (entry.language != language) continue;
      if (!entry.romanized.startsWith(q)) continue;
      // Deduplicate by English book name
      if (seen.add(entry.english)) {
        results.add(entry);
      }
      if (results.length >= 5) break;
    }
    return results;
  }
}
