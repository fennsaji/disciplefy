// Canonical Bible book names for scripture reference detection
//
// Single source of truth (canonical data): DB table `bible_book_config` (id = 1).
// - Frontend fetches via `get-bible-books` Edge Function and caches for 30 days.
// - Call [BibleBooks.loadRemoteData] after [BibleBooksService.initialize] to activate.
// - Static const lists below are fallback only (used on first launch / no network).
//
// Backend normalizer (bible-book-normalizer.ts) keeps its own hardcoded copy
// to avoid DB round-trips during LLM processing at cold-start.

import '../models/bible_books_config.dart';

/// Provides canonical Bible book names and utilities for scripture reference detection.
///
/// Supports remote data injection via [loadRemoteData]. Falls back to static
/// const lists when no remote config has been loaded.
class BibleBooks {
  // ---------------------------------------------------------------------------
  // Remote data support
  // ---------------------------------------------------------------------------

  static BibleBooksConfig? _remote;

  /// Called by [BibleBooksService] after loading from API or cache.
  /// Clears the cached regex so it rebuilds on the next call.
  static void loadRemoteData(BibleBooksConfig config) {
    _remote = config;
    _cachedPattern = null;
  }

  // ---------------------------------------------------------------------------
  // Static fallback data (used when remote config is not yet loaded)
  // ---------------------------------------------------------------------------

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
    'रोमियो', 'भजन-संहिता',
  ];

  /// Malayalam full forms and alternates (API uses abbreviated forms)
  static const List<String> malayalamAlternates = [
    // Full forms → abbreviated API forms
    'ഉല്പത്തി', 'പുറപ്പാട്', 'ലേവ്യപുസ്തകം', 'സംഖ്യാപുസ്തകം',
    'ആവർത്തനം', 'ആവർത്തനപുസ്തകം', 'ന്യായാധിപന്മാർ',
    '1 ശമൂവേൽ', '2 ശമൂവേൽ',
    '1 രാജാക്കന്മാർ', '2 രാജാക്കന്മാർ',
    '1 ദിനവൃത്താന്തം', '2 ദിനവൃത്താന്തം',
    'നെഹെമ്യാവ്', 'എസ്ഥേർ', 'ഇയ്യോബ്',
    'സങ്കീർത്തനങ്ങൾ', 'സദൃശവാക്യങ്ങൾ', 'സഭാപ്രസംഗി', 'ഉത്തമഗീതം',
    'യശായാ', 'യെശയ്യാവ്', 'യിരെമ്യാവ്', 'വിലാപങ്ങൾ', 'യെഹെസ്കേൽ', 'ദാനിയേൽ',
    'ഹോശേയ', 'യോവേൽ', 'ആമോസ്', 'ഓബദ്യാവ്',
    'ഹബക്കൂക്ക്', 'സെഫന്യാവ്', 'ഹഗ്ഗായി', 'സെഖര്യാവ്', 'മലാഖി',
    // New Testament full forms
    'മത്തായി', 'മർക്കൊസ്', 'ലൂക്കൊസ്', 'യോഹന്നാൻ',
    'അപ്പൊസ്തലപ്രവൃത്തികൾ', 'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ',
    'റോമാക്കാർ', 'റോമർ', 'റോമര്‍',
    '1 കൊരിന്ത്യർ', '2 കൊരിന്ത്യർ',
    'ഗലാത്യർ', 'എഫെസ്യർ', 'ഫിലിപ്പിയർ', 'കൊലൊസ്സ്യർ',
    'തെസ്സലൊനീക്യർ', '1 തെസ്സലൊനീക്യർ', '2 തെസ്സലൊനീക്യർ',
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
    // Additional spelling variants (from LOCALIZED_VARIANTS_TO_ENGLISH)
    'ലൂക്കാ', 'ലൂക്കോസ്', 'മർക്കോസ്', 'ജോൺ',
    'എഫേസ്യർ',
    'സങ്കീർത്തനം', 'സങ്കീര്‍ത്തനം',
    '1 പത്രോസ്', '2 പത്രോസ്',
  ];

  /// All Bible book names for all languages combined (including alternates).
  /// Uses remote data when loaded; falls back to static const lists.
  static List<String> get all {
    if (_remote != null) {
      return [
        ..._remote!.english,
        ..._remote!.englishAbbreviations,
        ..._remote!.hindi,
        ..._remote!.hindiAlternates,
        ..._remote!.malayalam,
        ..._remote!.malayalamAlternates,
      ];
    }
    return [
      ...english,
      ...englishAbbreviations,
      ...hindi,
      ...hindiAlternates,
      ...malayalam,
      ...malayalamAlternates,
    ];
  }

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

  static RegExp? _cachedPattern;

  /// Create RegExp for scripture reference detection.
  /// Result is cached after first call.
  static RegExp createScriptureRegex() {
    return _cachedPattern ??= RegExp(
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
        final matched = allAlternates[i];
        final matchedLower = matched.toLowerCase();

        // English alternates mapping (case-insensitive check)
        if (englishAbbreviations
            .any((abbr) => abbr.toLowerCase() == matchedLower)) {
          return _mapEnglishAlternateToCanonical(matched);
        }
        // Hindi alternates mapping (case-insensitive check)
        if (hindiAlternates.any((alt) => alt.toLowerCase() == matchedLower)) {
          return _mapHindiAlternateToCanonical(matched);
        }
        // Malayalam alternates mapping (case-insensitive check)
        if (malayalamAlternates
            .any((alt) => alt.toLowerCase() == matchedLower)) {
          return _mapMalayalamAlternateToCanonical(matched);
        }
      }
    }

    // If no match found, return original
    return trimmed;
  }

  /// Map English abbreviations to canonical names
  static String _mapEnglishAlternateToCanonical(String abbr) {
    // Comprehensive abbreviations to canonical mappings
    // Covers all entries in englishAbbreviations list
    final Map<String, String> mapping = {
      // Old Testament
      'Gen': 'Genesis', 'Ge': 'Genesis', 'Gn': 'Genesis',
      'Ex': 'Exodus', 'Exod': 'Exodus', 'Exo': 'Exodus',
      'Lev': 'Leviticus', 'Le': 'Leviticus', 'Lv': 'Leviticus',
      'Num': 'Numbers', 'Nu': 'Numbers', 'Nm': 'Numbers',
      'Deut': 'Deuteronomy', 'Dt': 'Deuteronomy', 'De': 'Deuteronomy',
      'Josh': 'Joshua', 'Jos': 'Joshua',
      'Judg': 'Judges', 'Jdg': 'Judges', 'Jg': 'Judges',
      'Ru': 'Ruth', 'Rth': 'Ruth',
      '1 Sam': '1 Samuel', '1Sam': '1 Samuel', '1Sa': '1 Samuel',
      '1 S': '1 Samuel',
      '2 Sam': '2 Samuel', '2Sam': '2 Samuel', '2Sa': '2 Samuel',
      '2 S': '2 Samuel',
      '1 Kgs': '1 Kings', '1Kgs': '1 Kings', '1Ki': '1 Kings', '1 K': '1 Kings',
      '2 Kgs': '2 Kings', '2Kgs': '2 Kings', '2Ki': '2 Kings', '2 K': '2 Kings',
      '1 Chr': '1 Chronicles', '1Chr': '1 Chronicles', '1Ch': '1 Chronicles',
      '2 Chr': '2 Chronicles', '2Chr': '2 Chronicles', '2Ch': '2 Chronicles',
      'Neh': 'Nehemiah', 'Ne': 'Nehemiah',
      'Est': 'Esther', 'Esth': 'Esther',
      'Ps': 'Psalms', 'Psa': 'Psalms', 'Psalm': 'Psalms', 'Psalms': 'Psalms',
      'Pss': 'Psalms',
      'Prov': 'Proverbs', 'Pr': 'Proverbs', 'Pro': 'Proverbs',
      'Proverb': 'Proverbs',
      'Eccl': 'Ecclesiastes', 'Ec': 'Ecclesiastes', 'Ecc': 'Ecclesiastes',
      'Song': 'Song of Solomon', 'SoS': 'Song of Solomon',
      'SS': 'Song of Solomon',
      'Song of Songs': 'Song of Solomon',
      'Isa': 'Isaiah', 'Is': 'Isaiah',
      'Jer': 'Jeremiah', 'Je': 'Jeremiah', 'Jr': 'Jeremiah',
      'Lam': 'Lamentations', 'La': 'Lamentations',
      'Ezek': 'Ezekiel', 'Eze': 'Ezekiel', 'Ezk': 'Ezekiel',
      'Dan': 'Daniel', 'Da': 'Daniel', 'Dn': 'Daniel',
      'Hos': 'Hosea', 'Ho': 'Hosea',
      'Joe': 'Joel', 'Jl': 'Joel',
      'Am': 'Amos',
      'Obad': 'Obadiah', 'Ob': 'Obadiah',
      'Jon': 'Jonah', 'Jnh': 'Jonah',
      'Mic': 'Micah', 'Mc': 'Micah',
      'Nah': 'Nahum', 'Na': 'Nahum',
      'Hab': 'Habakkuk', 'Hb': 'Habakkuk',
      'Zeph': 'Zephaniah', 'Zep': 'Zephaniah', 'Zp': 'Zephaniah',
      'Hag': 'Haggai', 'Hg': 'Haggai',
      'Zech': 'Zechariah', 'Zec': 'Zechariah', 'Zc': 'Zechariah',
      'Mal': 'Malachi', 'Ml': 'Malachi',
      // New Testament
      'Matt': 'Matthew', 'Mt': 'Matthew',
      'The Gospel of Matthew': 'Matthew',
      'Mk': 'Mark', 'Mr': 'Mark',
      'The Gospel of Mark': 'Mark',
      'Lk': 'Luke', 'Luk': 'Luke',
      'The Gospel of Luke': 'Luke',
      'Jn': 'John', 'Joh': 'John',
      'The Gospel of John': 'John',
      'Ac': 'Acts',
      'Rom': 'Romans', 'Ro': 'Romans', 'Rm': 'Romans',
      '1 Cor': '1 Corinthians', '1Cor': '1 Corinthians', '1Co': '1 Corinthians',
      'First Corinthians': '1 Corinthians', '1st Corinthians': '1 Corinthians',
      '2 Cor': '2 Corinthians', '2Cor': '2 Corinthians', '2Co': '2 Corinthians',
      'Second Corinthians': '2 Corinthians', '2nd Corinthians': '2 Corinthians',
      'Gal': 'Galatians', 'Ga': 'Galatians',
      'Eph': 'Ephesians', 'Ep': 'Ephesians',
      'Phil': 'Philippians', 'Php': 'Philippians', 'Pp': 'Philippians',
      'Col': 'Colossians', 'Co': 'Colossians',
      '1 Thess': '1 Thessalonians', '1Thess': '1 Thessalonians',
      '1Th': '1 Thessalonians',
      'First Thessalonians': '1 Thessalonians',
      '1st Thessalonians': '1 Thessalonians',
      '2 Thess': '2 Thessalonians', '2Thess': '2 Thessalonians',
      '2Th': '2 Thessalonians',
      'Second Thessalonians': '2 Thessalonians',
      '2nd Thessalonians': '2 Thessalonians',
      '1 Tim': '1 Timothy', '1Tim': '1 Timothy', '1Ti': '1 Timothy',
      'First Timothy': '1 Timothy', '1st Timothy': '1 Timothy',
      '2 Tim': '2 Timothy', '2Tim': '2 Timothy', '2Ti': '2 Timothy',
      'Second Timothy': '2 Timothy', '2nd Timothy': '2 Timothy',
      'Tit': 'Titus', 'Ti': 'Titus',
      'Phlm': 'Philemon', 'Phm': 'Philemon', 'Pm': 'Philemon',
      'Heb': 'Hebrews', 'He': 'Hebrews',
      'Jas': 'James', 'Jm': 'James',
      '1 Pet': '1 Peter', '1Pet': '1 Peter', '1Pe': '1 Peter', '1P': '1 Peter',
      'First Peter': '1 Peter', '1st Peter': '1 Peter',
      '2 Pet': '2 Peter', '2Pet': '2 Peter', '2Pe': '2 Peter', '2P': '2 Peter',
      'Second Peter': '2 Peter', '2nd Peter': '2 Peter',
      '1 Jn': '1 John', '1Jn': '1 John', '1Jo': '1 John',
      'First John': '1 John', '1st John': '1 John',
      '2 Jn': '2 John', '2Jn': '2 John', '2Jo': '2 John',
      'Second John': '2 John', '2nd John': '2 John',
      '3 Jn': '3 John', '3Jn': '3 John', '3Jo': '3 John',
      'Third John': '3 John', '3rd John': '3 John',
      'Jud': 'Jude',
      'Rev': 'Revelation', 'Re': 'Revelation', 'Rv': 'Revelation',
      'Revelations': 'Revelation',
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
