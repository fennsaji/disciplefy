// Canonical Bible book names for scripture reference detection
// Mirrors backend: supabase/functions/_shared/utils/bible-book-normalizer.ts
//
// This file should be kept in sync with the backend canonical book names.
// These are the official book names used by API.Bible service.

/// Provides canonical Bible book names and utilities for scripture reference detection
class BibleBooks {
  /// English Bible book names (API.Bible - KJV/ESV)
  static const List<String> english = [
    // Old Testament
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai',
    'Zechariah', 'Malachi',
    // New Testament
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians',
    'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
    '2 Timothy',
    'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation',
  ];

  /// Hindi Bible book names (API.Bible - Indian Revised Version Hindi 2019)
  static const List<String> hindi = [
    // Old Testament (Hindi)
    'उत्पत्ति', 'निर्गमन', 'लैव्यव्यवस्था', 'गिनती', 'व्यवस्थाविवरण',
    'यहोशू', 'न्यायियों', 'रूत', '1 शमूएल', '2 शमूएल', '1 राजाओं', '2 राजाओं',
    '1 इतिहास', '2 इतिहास', 'एज्रा', 'नहेम्याह', 'एस्तेर', 'अय्यूब',
    'भजन संहिता', 'नीतिवचन', 'सभोपदेशक', 'श्रेष्ठगीत', 'यशायाह',
    'यिर्मयाह', 'विलापगीत', 'यहेजकेल', 'दानिय्येल', 'होशे', 'योएल', 'आमोस',
    'ओबद्याह', 'योना', 'मीका', 'नहूम', 'हबक्कूक', 'सपन्याह', 'हाग्गै',
    'जकर्याह', 'मलाकी',
    // New Testament (Hindi)
    'मत्ती', 'मरकुस', 'लूका', 'यूहन्ना', 'प्रेरितों के काम', 'रोमियों',
    '1 कुरिन्थियों', '2 कुरिन्थियों', 'गलातियों', 'इफिसियों', 'फिलिप्पियों',
    'कुलुस्सियों', '1 थिस्सलुनीकियों', '2 थिस्सलुनीकियों', '1 तीमुथियुस',
    '2 तीमुथियुस',
    'तीतुस', 'फिलेमोन', 'इब्रानियों', 'याकूब', '1 पतरस', '2 पतरस',
    '1 यूहन्ना', '2 यूहन्ना', '3 यूहन्ना', 'यहूदा', 'प्रकाशितवाक्य',
  ];

  /// Malayalam Bible book names (API.Bible - Indian Revised Version Malayalam 2025)
  /// These are abbreviated forms with periods as used in the official Malayalam Bible
  static const List<String> malayalam = [
    // Old Testament (Malayalam)
    'ഉല്പ.', 'പുറ.', 'ലേവ്യ.', 'സംഖ്യ.', 'ആവർ.',
    'യോശുവ', 'ന്യായാ.', 'രൂത്ത്', '1 ശമു.', '2 ശമു.',
    '1 രാജാ.', '2 രാജാ.', '1 ദിന.', '2 ദിന.',
    'എസ്രാ', 'നെഹെ.', 'എസ്ഥേ.', 'ഇയ്യോ.', 'സങ്കീ.', 'സദൃ.',
    'സഭാ.', 'ഉത്ത.', 'യെശ.', 'യിരെ.', 'വിലാ.',
    'യെഹെ.', 'ദാനീ.', 'ഹോശേ.', 'യോവേ.', 'ആമോ.', 'ഓബ.',
    'യോനാ', 'മീഖാ', 'നഹൂം', 'ഹബ.', 'സെഫ.', 'ഹഗ്ഗാ.',
    'സെഖ.', 'മലാ.',
    // New Testament (Malayalam)
    'മത്താ.', 'മർക്കൊ.', 'ലൂക്കൊ.', 'യോഹ.', 'പ്രവൃത്തികൾ', 'റോമ.',
    '1 കൊരി.', '2 കൊരി.', 'ഗലാ.', 'എഫെ.', 'ഫിലി.',
    'കൊലൊ.', '1 തെസ്സ.', '2 തെസ്സ.', '1 തിമൊ.', '2 തിമൊ.',
    'തീത്തൊ.', 'ഫിലേ.', 'എബ്രാ.', 'യാക്കോ.', '1 പത്രൊ.', '2 പത്രൊ.',
    '1 യോഹ.', '2 യോഹ.', '3 യോഹ.', 'യൂദാ', 'വെളി.',
  ];

  /// English abbreviations and alternate names
  static const List<String> englishAbbreviations = [
    // Common abbreviations
    'Gen', 'Ge', 'Gn', 'Ex', 'Exod', 'Exo', 'Lev', 'Le', 'Lv',
    'Num', 'Nu', 'Nm', 'Deut', 'Dt', 'De', 'Josh', 'Jos',
    'Judg', 'Jdg', 'Jg', 'Ru', 'Rth',
    '1 Sam', '1Sam', '1Sa', '1 S', '2 Sam', '2Sam', '2Sa', '2 S',
    '1 Kgs', '1Kgs', '1Ki', '1 K', '2 Kgs', '2Kgs', '2Ki', '2 K',
    '1 Chr', '1Chr', '1Ch', '2 Chr', '2Chr', '2Ch',
    'Neh', 'Ne', 'Est', 'Esth',
    'Ps', 'Psa', 'Psalm', 'Psalms', 'Pss', 'Prov', 'Pr', 'Pro',
    'Eccl', 'Ec', 'Ecc', 'Song', 'SoS', 'SS',
    'Isa', 'Is', 'Jer', 'Je', 'Jr', 'Lam', 'La',
    'Ezek', 'Eze', 'Ezk', 'Dan', 'Da', 'Dn',
    'Hos', 'Ho', 'Joe', 'Jl', 'Am', 'Obad', 'Ob',
    'Jon', 'Jnh', 'Mic', 'Mc', 'Nah', 'Na',
    'Hab', 'Hb', 'Zeph', 'Zep', 'Zp', 'Hag', 'Hg',
    'Zech', 'Zec', 'Zc', 'Mal', 'Ml',
    // New Testament abbreviations
    'Matt', 'Mt', 'Mk', 'Mr', 'Lk', 'Luk', 'Jn', 'Joh', 'Ac',
    'Rom', 'Ro', 'Rm',
    '1 Cor', '1Cor', '1Co', '2 Cor', '2Cor', '2Co',
    'Gal', 'Ga', 'Eph', 'Ep', 'Phil', 'Php', 'Pp',
    'Col', 'Co',
    '1 Thess', '1Thess', '1Th', '2 Thess', '2Thess', '2Th',
    '1 Tim', '1Tim', '1Ti', '2 Tim', '2Tim', '2Ti',
    'Tit', 'Ti', 'Phlm', 'Phm', 'Pm', 'Heb', 'He',
    'Jas', 'Jm',
    '1 Pet', '1Pet', '1Pe', '1P', '2 Pet', '2Pet', '2Pe', '2P',
    '1 Jn', '1Jn', '1Jo', '2 Jn', '2Jn', '2Jo', '3 Jn', '3Jn', '3Jo',
    'Jud', 'Rev', 'Re', 'Rv',
    // Alternate names
    'Song of Songs', 'Revelations', 'Proverb',
    'First Corinthians', 'Second Corinthians',
    'First Thessalonians', 'Second Thessalonians',
    'First Timothy', 'Second Timothy',
    'First Peter', 'Second Peter',
    'First John', 'Second John', 'Third John',
    '1st Corinthians', '2nd Corinthians',
    '1st Thessalonians', '2nd Thessalonians',
    '1st Timothy', '2nd Timothy',
    '1st Peter', '2nd Peter',
    '1st John', '2nd John', '3rd John',
    'The Gospel of John', 'The Gospel of Matthew',
    'The Gospel of Mark', 'The Gospel of Luke',
  ];

  /// Hindi abbreviations and alternate spellings
  static const List<String> hindiAlternates = [
    // Abbreviations
    'भज', 'भजन', 'प्रेरितों',
    // Word-based numbers to numerals
    'पहला शमूएल', 'दूसरा शमूएल',
    'पहला राजाओं', 'दूसरा राजाओं',
    'पहला इतिहास', 'दूसरा इतिहास',
    'पहला कुरिन्थियों', 'दूसरा कुरिन्थियों',
    'पहला थिस्सलुनीकियों', 'दूसरा थिस्सलुनीकियों',
    'पहला तीमुथियुस', 'दूसरा तीमुथियुस',
    'पहला पतरस', 'दूसरा पतरस',
    'पहला यूहन्ना', 'दूसरा यूहन्ना', 'तीसरा यूहन्ना',
    // Common misspellings
    'मर्कुस', // Common misspelling of मरकुस
    'नहेमायाह', // Alternative spelling of नहेम्याह
    '1 राजा', '2 राजा', // Singular vs plural
  ];

  /// Malayalam full forms and alternates (API uses abbreviated forms)
  static const List<String> malayalamAlternates = [
    // Full forms to abbreviated forms
    'ഉല്പത്തി', 'പുറപ്പാട്', 'ലേവ്യപുസ്തകം', 'സംഖ്യാപുസ്തകം',
    'ആവർത്തനം', 'ന്യായാധിപന്മാർ',
    '1 ശമൂവേൽ', '2 ശമൂവേൽ',
    '1 രാജാക്കന്മാർ', '2 രാജാക്കന്മാർ',
    '1 ദിനവൃത്താന്തം', '2 ദിനവൃത്താന്തം',
    'നെഹെമ്യാവ്', 'എസ്ഥേർ', 'ഇയ്യോബ്',
    'സങ്കീർത്തനങ്ങൾ', 'സദൃശവാക്യങ്ങൾ', 'സഭാപ്രസംഗി', 'ഉത്തമഗീതം',
    'യശായാ', 'യിരെമ്യാവ്', 'വിലാപങ്ങൾ', 'യെഹെസ്കേൽ', 'ദാനിയേൽ',
    'ഹോശേയ', 'യോവേൽ', 'ആമോസ്', 'ഓബദ്യാവ്',
    'ഹബക്കൂക്ക്', 'സെഫന്യാവ്', 'ഹഗ്ഗായി', 'സെഖര്യാവ്', 'മലാഖി',
    // New Testament full forms
    'മത്തായി', 'മർക്കൊസ്', 'ലൂക്കൊസ്', 'യോഹന്നാൻ',
    'അപ്പൊസ്തലപ്രവൃത്തികൾ', 'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ',
    'റോമാക്കാർ',
    '1 കൊരിന്ത്യർ', '2 കൊരിന്ത്യർ',
    'ഗലാത്യർ', 'എഫെസ്യർ', 'ഫിലിപ്പിയർ', 'കൊലൊസ്സ്യർ',
    '1 തെസ്സലൊനീക്യർ', '2 തെസ്സലൊനീക്യർ',
    '1 തിമൊഥെയൊസ്', '2 തിമൊഥെയൊസ്',
    'തീത്തൊസ്', 'ഫിലേമോൻ', 'എബ്രായർ', 'യാക്കോബ്',
    '1 പത്രൊസ്', '2 പത്രൊസ്',
    '1 യോഹന്നാൻ', '2 യോഹന്നാൻ', '3 യോഹന്നാൻ',
    'വെളിപ്പാട്',
    // Word-based numbers
    'ഒന്നാം ശമൂവേൽ', 'രണ്ടാം ശമൂവേൽ',
    'ഒന്നാം രാജാക്കന്മാർ', 'രണ്ടാം രാജാക്കന്മാർ',
    'ഒന്നാം കൊരിന്ത്യർ', 'രണ്ടാം കൊരിന്ത്യർ',
    'ഒന്നാം തെസ്സലൊനീക്യർ', 'രണ്ടാം തെസ്സലൊനീക്യർ',
    'ഒന്നാം തിമൊഥെയൊസ്', 'രണ്ടാം തിമൊഥെയൊസ്',
    'ഒന്നാം പത്രൊസ്', 'രണ്ടാം പത്രൊസ്',
    'ഒന്നാം യോഹന്നാൻ', 'രണ്ടാം യോഹന്നാൻ', 'മൂന്നാം യോഹന്നാൻ',
  ];

  /// Get all Bible book names for all languages combined (including alternates)
  static List<String> get all => [
        ...english,
        ...englishAbbreviations,
        ...hindi,
        ...hindiAlternates,
        ...malayalam,
        ...malayalamAlternates,
      ];

  /// Generate regex pattern for scripture reference detection
  /// Requires chapter number to avoid false matches
  static String getScripturePattern() {
    // Escape special regex characters in book names
    final escapedBooks = all.map(_escapeRegex).toList();

    // Sort by length descending to match longer names first
    // (e.g., "भजन संहिता" before single words)
    escapedBooks.sort((a, b) => b.length.compareTo(a.length));

    final booksPattern = escapedBooks.join('|');

    // Pattern: (BookName) Chapter:Verse or (BookName) Chapter
    // Requires chapter number to prevent false matches like "Point 1"
    return r'(' + booksPattern + r')' + r'\s+(\d+)(?::(\d+)(?:-(\d+))?)?';
  }

  /// Escape special regex characters
  static String _escapeRegex(String str) {
    return str.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (match) => '\\${match.group(0)}',
    );
  }

  /// Create RegExp for scripture reference detection
  static RegExp createScriptureRegex() {
    return RegExp(
      getScripturePattern(),
      unicode: true,
      caseSensitive: false, // Allow "john" or "John"
    );
  }

  /// Normalize book name to canonical form
  /// Returns the canonical book name if found, otherwise returns the original
  static String normalizeBookName(String bookName) {
    final trimmed = bookName.trim();

    // Check if already canonical (case-insensitive)
    for (final canonical in [...english, ...hindi, ...malayalam]) {
      if (canonical.toLowerCase() == trimmed.toLowerCase()) {
        return canonical;
      }
    }

    // Check abbreviations and alternates (case-insensitive)
    final allAlternates = [
      ...englishAbbreviations,
      ...hindiAlternates,
      ...malayalamAlternates,
    ];

    for (int i = 0; i < allAlternates.length; i++) {
      if (allAlternates[i].toLowerCase() == trimmed.toLowerCase()) {
        // Find which canonical list this alternate belongs to
        // and map to the appropriate canonical name
        final alternate = allAlternates[i];

        // English alternates mapping
        if (englishAbbreviations.contains(alternate)) {
          return _mapEnglishAlternateToCanonical(alternate);
        }
        // Hindi alternates mapping
        if (hindiAlternates.contains(alternate)) {
          return _mapHindiAlternateToCanonical(alternate);
        }
        // Malayalam alternates mapping
        if (malayalamAlternates.contains(alternate)) {
          return _mapMalayalamAlternateToCanonical(alternate);
        }
      }
    }

    // If no match found, return original
    return trimmed;
  }

  /// Map English abbreviations to canonical names
  static String _mapEnglishAlternateToCanonical(String abbr) {
    // Common abbreviations to canonical mappings
    final Map<String, String> mapping = {
      'Psalm': 'Psalms',
      'Ps': 'Psalms',
      'Psa': 'Psalms',
      'Pss': 'Psalms',
      'Gen': 'Genesis',
      'Ge': 'Genesis',
      'Gn': 'Genesis',
      'Ex': 'Exodus',
      'Exod': 'Exodus',
      'Exo': 'Exodus',
      'Matt': 'Matthew',
      'Mt': 'Matthew',
      'Eph': 'Ephesians',
      'Ep': 'Ephesians',
      'Rev': 'Revelation',
      'Re': 'Revelation',
      'Rv': 'Revelation',
      'Revelations': 'Revelation',
      // Add more as needed
    };

    return mapping[abbr] ?? abbr;
  }

  /// Map Hindi alternates to canonical names
  static String _mapHindiAlternateToCanonical(String alternate) {
    final Map<String, String> mapping = {
      'भज': 'भजन संहिता',
      'भजन': 'भजन संहिता',
      'प्रेरितों': 'प्रेरितों के काम',
    };

    return mapping[alternate] ?? alternate;
  }

  /// Map Malayalam alternates to canonical names
  static String _mapMalayalamAlternateToCanonical(String alternate) {
    final Map<String, String> mapping = {
      'ഉല്പത്തി': 'ഉല്പ.',
      'യോഹന്നാൻ': 'യോഹ.',
      'അപ്പൊസ്തലപ്രവൃത്തികൾ': 'പ്രവൃത്തികൾ',
    };

    return mapping[alternate] ?? alternate;
  }
}
