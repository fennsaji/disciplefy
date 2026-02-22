/**
 * Bible Book Name Normalizer
 *
 * Validates and auto-corrects Bible book names in LLM responses.
 * Supports English, Hindi, and Malayalam with fuzzy matching.
 *
 * Usage:
 * ```typescript
 * const normalizer = new BibleBookNormalizer()
 * const correctedText = normalizer.normalizeBibleBooks(llmResponse, 'en-US')
 * const validation = normalizer.validateBibleBooks(llmResponse, 'en-US')
 * ```
 */

// ==================== CANONICAL BIBLE BOOK NAMES ====================

export const CANONICAL_BIBLE_BOOKS = {
  'en-US': [
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
    'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
    'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation'
  ],
  'hi-IN': [
    // Official book names from API.Bible - Indian Revised Version Hindi 2019
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
    'कुलुस्सियों', '1 थिस्सलुनीकियों', '2 थिस्सलुनीकियों', '1 तीमुथियुस', '2 तीमुथियुस',
    'तीतुस', 'फिलेमोन', 'इब्रानियों', 'याकूब', '1 पतरस', '2 पतरस',
    '1 यूहन्ना', '2 यूहन्ना', '3 यूहन्ना', 'यहूदा', 'प्रकाशितवाक्य'
  ],
  'ml-IN': [
    // Official book names from API.Bible - Indian Revised Version Malayalam 2025
    // These are abbreviated forms with periods as used in the official Malayalam Bible
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
    '1 യോഹ.', '2 യോഹ.', '3 യോഹ.', 'യൂദാ', 'വെളി.'
  ]
} as const

// ==================== LOCALIZED DISPLAY NAMES ====================

/**
 * Maps English book names to their canonical Hindi full names.
 * Used for localized display and reverse lookup (e.g., in fetch-verse).
 * Source of truth for Hindi display names shared across all backend functions.
 */
export const HINDI_BOOK_NAMES: Record<string, string> = {
  // Old Testament
  'Genesis': 'उत्पत्ति', 'Exodus': 'निर्गमन', 'Leviticus': 'लैव्यव्यवस्था', 'Numbers': 'गिनती', 'Deuteronomy': 'व्यवस्थाविवरण',
  'Joshua': 'यहोशू', 'Judges': 'न्यायियों', 'Ruth': 'रूत', '1 Samuel': '1 शमूएल', '2 Samuel': '2 शमूएल',
  '1 Kings': '1 राजा', '2 Kings': '2 राजा', '1 Chronicles': '1 इतिहास', '2 Chronicles': '2 इतिहास',
  'Ezra': 'एज्रा', 'Nehemiah': 'नहेमायाह', 'Esther': 'एस्तेर', 'Job': 'अय्यूब', 'Psalms': 'भजन संहिता',
  'Proverbs': 'नीतिवचन', 'Ecclesiastes': 'सभोपदेशक', 'Song of Solomon': 'श्रेष्ठगीत', 'Isaiah': 'यशायाह',
  'Jeremiah': 'यिर्मयाह', 'Lamentations': 'विलापगीत', 'Ezekiel': 'यहेजकेल', 'Daniel': 'दानिय्येल',
  'Hosea': 'होशे', 'Joel': 'योएल', 'Amos': 'आमोस', 'Obadiah': 'ओबद्याह', 'Jonah': 'योना',
  'Micah': 'मीका', 'Nahum': 'नहूम', 'Habakkuk': 'हबक्कूक', 'Zephaniah': 'सपन्याह', 'Haggai': 'हाग्गै',
  'Zechariah': 'जकर्याह', 'Malachi': 'मलाकी',
  // New Testament
  'Matthew': 'मत्ती', 'Mark': 'मरकुस', 'Luke': 'लूका', 'John': 'यूहन्ना', 'Acts': 'प्रेरितों के काम',
  'Romans': 'रोमियों', '1 Corinthians': '1 कुरिन्थियों', '2 Corinthians': '2 कुरिन्थियों', 'Galatians': 'गलातियों',
  'Ephesians': 'इफिसियों', 'Philippians': 'फिलिप्पियों', 'Colossians': 'कुलुस्सियों', '1 Thessalonians': '1 थिस्सलुनीकियों',
  '2 Thessalonians': '2 थिस्सलुनीकियों', '1 Timothy': '1 तीमुथियुस', '2 Timothy': '2 तीमुथियुस', 'Titus': 'तीतुस',
  'Philemon': 'फिलेमोन', 'Hebrews': 'इब्रानियों', 'James': 'याकूब', '1 Peter': '1 पतरस', '2 Peter': '2 पतरस',
  '1 John': '1 यूहन्ना', '2 John': '2 यूहन्ना', '3 John': '3 यूहन्ना', 'Jude': 'यहूदा', 'Revelation': 'प्रकाशितवाक्य',
}

/**
 * Maps English book names to their canonical Malayalam full names (for display).
 * Note: CANONICAL_BIBLE_BOOKS['ml-IN'] uses abbreviated API forms (e.g., 'ഉല്പ.');
 * these are full-form display names used for user-facing localization.
 * Source of truth for Malayalam display names shared across all backend functions.
 */
export const MALAYALAM_BOOK_NAMES: Record<string, string> = {
  // Old Testament
  'Genesis': 'ഉല്പത്തി', 'Exodus': 'പുറപ്പാട്', 'Leviticus': 'ലേവ്യപുസ്തകം', 'Numbers': 'സംഖ്യാപുസ്തകം', 'Deuteronomy': 'ആവര്‍ത്തനം',
  'Joshua': 'യോശുവ', 'Judges': 'ന്യായാധിപന്മാര്‍', 'Ruth': 'രൂത്ത്', '1 Samuel': '1 ശമൂവേല്‍', '2 Samuel': '2 ശമൂവേല്‍',
  '1 Kings': '1 രാജാക്കന്മാര്‍', '2 Kings': '2 രാജാക്കന്മാര്‍', '1 Chronicles': '1 ദിനവൃത്താന്തം', '2 Chronicles': '2 ദിനവൃത്താന്തം',
  'Ezra': 'എസ്രാ', 'Nehemiah': 'നെഹെമ്യാവ്', 'Esther': 'എസ്ഥേര്‍', 'Job': 'ഇയ്യോബ്', 'Psalms': 'സങ്കീര്‍ത്തനങ്ങള്‍',
  'Proverbs': 'സദൃശവാക്യങ്ങള്‍', 'Ecclesiastes': 'സഭാപ്രസംഗി', 'Song of Solomon': 'ഉത്തമഗീതം', 'Isaiah': 'യശായാ',
  'Jeremiah': 'യിരെമ്യാവ്', 'Lamentations': 'വിലാപങ്ങള്‍', 'Ezekiel': 'യെഹെസ്കേല്‍', 'Daniel': 'ദാനീയേല്‍',
  'Hosea': 'ഹോശേയ', 'Joel': 'യോവേല്‍', 'Amos': 'ആമോസ്', 'Obadiah': 'ഓബദ്യാവ്', 'Jonah': 'യോനാ',
  'Micah': 'മീഖാ', 'Nahum': 'നഹൂം', 'Habakkuk': 'ഹബക്കൂക്ക്', 'Zephaniah': 'സെഫന്യാവ്', 'Haggai': 'ഹഗ്ഗായി',
  'Zechariah': 'സെഖര്യാവ്', 'Malachi': 'മലാഖി',
  // New Testament
  'Matthew': 'മത്തായി', 'Mark': 'മര്‍ക്കൊസ്', 'Luke': 'ലൂക്കൊസ്', 'John': 'യോഹന്നാന്‍', 'Acts': 'അപ്പൊസ്തലപ്രവൃത്തികള്‍',
  'Romans': 'റോമാക്കാര്‍', '1 Corinthians': '1 കൊരിന്ത്യര്‍', '2 Corinthians': '2 കൊരിന്ത്യര്‍', 'Galatians': 'ഗലാത്യര്‍',
  'Ephesians': 'എഫെസ്യര്‍', 'Philippians': 'ഫിലിപ്പിയര്‍', 'Colossians': 'കൊലൊസ്സ്യര്‍', '1 Thessalonians': '1 തെസ്സലൊനീക്യര,‍',
  '2 Thessalonians': '2 തെസ്സലൊനീക്യര്‍', '1 Timothy': '1 തിമൊഥെയൊസ്', '2 Timothy': '2 തിമൊഥെയൊസ്', 'Titus': 'തീത്തൊസ്',
  'Philemon': 'ഫിലേമോന്‍', 'Hebrews': 'എബ്രായര്‍', 'James': 'യാക്കോബ്', '1 Peter': '1 പത്രൊസ്', '2 Peter': '2 പത്രൊസ്',
  '1 John': '1 യോഹന്നാന്‍', '2 John': '2 യോഹന്നാന്‍', '3 John': '3 യോഹന്നാന്‍', 'Jude': 'യൂദാ', 'Revelation': 'വെളിപ്പാട്',
}

/**
 * Maps common LLM-generated and user-input book name variants to their English canonical names.
 * Includes Malayalam and Hindi alternate spellings not covered by the canonical display name maps.
 *
 * This is the single source of truth for variant → English mappings used across all
 * backend functions (fetch-verse, future functions, etc.).
 *
 * Add new LLM-generated variants here when discovered to fix them everywhere at once.
 */
export const LOCALIZED_VARIANTS_TO_ENGLISH: Record<string, string> = {
  // Malayalam API abbreviated forms (CANONICAL_BIBLE_BOOKS['ml-IN']) → English
  // These are sent verbatim by the frontend passage section when tapping a reference.
  'ഉല്പ.': 'Genesis',
  'പുറ.': 'Exodus',
  'ലേവ്യ.': 'Leviticus',
  'സംഖ്യ.': 'Numbers',
  'ആവർ.': 'Deuteronomy',
  'ന്യായാ.': 'Judges',
  'രൂത്ത്': 'Ruth',
  '1 ശമു.': '1 Samuel',
  '2 ശമു.': '2 Samuel',
  '1 രാജാ.': '1 Kings',
  '2 രാജാ.': '2 Kings',
  '1 ദിന.': '1 Chronicles',
  '2 ദിന.': '2 Chronicles',
  'നെഹെ.': 'Nehemiah',
  'എസ്ഥേ.': 'Esther',
  'ഇയ്യോ.': 'Job',
  'സങ്കീ.': 'Psalms',
  'സദൃ.': 'Proverbs',
  'സഭാ.': 'Ecclesiastes',
  'ഉത്ത.': 'Song of Solomon',
  'യെശ.': 'Isaiah',
  'യിരെ.': 'Jeremiah',
  'വിലാ.': 'Lamentations',
  'യെഹെ.': 'Ezekiel',
  'ദാനീ.': 'Daniel',
  'ഹോശേ.': 'Hosea',
  'യോവേ.': 'Joel',
  'ആമോ.': 'Amos',
  'ഓബ.': 'Obadiah',
  'യോനാ': 'Jonah',
  'മീഖാ': 'Micah',
  'നഹൂം': 'Nahum',
  'ഹബ.': 'Habakkuk',
  'സെഫ.': 'Zephaniah',
  'ഹഗ്ഗാ.': 'Haggai',
  'സെഖ.': 'Zechariah',
  'മലാ.': 'Malachi',
  'മത്താ.': 'Matthew',
  'മർക്കൊ.': 'Mark',
  'ലൂക്കൊ.': 'Luke',
  'യോഹ.': 'John',
  'പ്രവൃത്തികൾ': 'Acts',
  'റോമ.': 'Romans',
  '1 കൊരി.': '1 Corinthians',
  '2 കൊരി.': '2 Corinthians',
  'ഗലാ.': 'Galatians',
  'എഫെ.': 'Ephesians',
  'ഫിലി.': 'Philippians',
  'കൊലൊ.': 'Colossians',
  '1 തെസ്സ.': '1 Thessalonians',
  '2 തെസ്സ.': '2 Thessalonians',
  '1 തിമൊ.': '1 Timothy',
  '2 തിമൊ.': '2 Timothy',
  'തീത്തൊ.': 'Titus',
  'ഫിലേ.': 'Philemon',
  'എബ്രാ.': 'Hebrews',
  'യാക്കോ.': 'James',
  '1 പത്രൊ.': '1 Peter',
  '2 പത്രൊ.': '2 Peter',
  '1 യോഹ.': '1 John',
  '2 യോഹ.': '2 John',
  '3 യോഹ.': '3 John',
  'യൂദാ': 'Jude',
  'വെളി.': 'Revelation',
  // Malayalam full forms → English (covers all entries in INCORRECT_TO_CORRECT['ml-IN'])
  // Duplicating here so fetch-verse can resolve them without going through the abbreviated API form.
  'ഉല്പത്തി': 'Genesis',
  'പുറപ്പാട്': 'Exodus',
  'ലേവ്യപുസ്തകം': 'Leviticus',
  'സംഖ്യാപുസ്തകം': 'Numbers',
  'ആവർത്തനം': 'Deuteronomy',
  'ആവർത്തനപുസ്തകം': 'Deuteronomy',
  'ന്യായാധിപന്മാർ': 'Judges',
  '1 ശമൂവേൽ': '1 Samuel',
  '2 ശമൂവേൽ': '2 Samuel',
  '1 രാജാക്കന്മാർ': '1 Kings',
  '2 രാജാക്കന്മാർ': '2 Kings',
  '1 ദിനവൃത്താന്തം': '1 Chronicles',
  '2 ദിനവൃത്താന്തം': '2 Chronicles',
  'നെഹെമ്യാവ്': 'Nehemiah',
  'എസ്ഥേർ': 'Esther',
  'ഇയ്യോബ്': 'Job',
  'സദൃശവാക്യങ്ങൾ': 'Proverbs',
  'സഭാപ്രസംഗി': 'Ecclesiastes',
  'ഉത്തമഗീതം': 'Song of Solomon',
  'യശായാ': 'Isaiah',
  'യെശയ്യാവ്': 'Isaiah',
  'യിരെമ്യാവ്': 'Jeremiah',
  'വിലാപങ്ങൾ': 'Lamentations',
  'യെഹെസ്കേൽ': 'Ezekiel',
  'ദാനിയേൽ': 'Daniel',
  'ഹോശേയ': 'Hosea',
  'യോവേൽ': 'Joel',
  'ആമോസ്': 'Amos',
  'ഓബദ്യാവ്': 'Obadiah',
  'ഹബക്കൂക്ക്': 'Habakkuk',
  'സെഫന്യാവ്': 'Zephaniah',
  'ഹഗ്ഗായി': 'Haggai',
  'സെഖര്യാവ്': 'Zechariah',
  'മലാഖി': 'Malachi',
  'മത്തായി': 'Matthew',
  'മർക്കൊസ്': 'Mark',
  'ലൂക്കൊസ്': 'Luke',
  'യോഹന്നാൻ': 'John',
  'അപ്പൊസ്തലപ്രവൃത്തികൾ': 'Acts',
  'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ': 'Acts',
  'റോമാക്കാർ': 'Romans',
  '1 കൊരിന്ത്യർ': '1 Corinthians',
  '2 കൊരിന്ത്യർ': '2 Corinthians',
  '1 തിമൊഥെയൊസ്': '1 Timothy',
  '2 തിമൊഥെയൊസ്': '2 Timothy',
  'തീത്തൊസ്': 'Titus',
  'ഫിലേമോൻ': 'Philemon',
  'യാക്കോബ്': 'James',
  '1 പത്രൊസ്': '1 Peter',
  '2 പത്രൊസ്': '2 Peter',
  'വെളിപ്പാട്': 'Revelation',
  // Malayalam word-based number variants
  'ഒന്നാം ശമൂവേൽ': '1 Samuel',
  'രണ്ടാം ശമൂവേൽ': '2 Samuel',
  'ഒന്നാം രാജാക്കന്മാർ': '1 Kings',
  'രണ്ടാം രാജാക്കന്മാർ': '2 Kings',
  'ഒന്നാം കൊരിന്ത്യർ': '1 Corinthians',
  'രണ്ടാം കൊരിന്ത്യർ': '2 Corinthians',
  'ഒന്നാം തെസ്സലൊനീക്യർ': '1 Thessalonians',
  'രണ്ടാം തെസ്സലൊനീക്യർ': '2 Thessalonians',
  'ഒന്നാം തിമൊഥെയൊസ്': '1 Timothy',
  'രണ്ടാം തിമൊഥെയൊസ്': '2 Timothy',
  'ഒന്നാം പത്രൊസ്': '1 Peter',
  'രണ്ടാം പത്രൊസ്': '2 Peter',
  'ഒന്നാം യോഹന്നാൻ': '1 John',
  'രണ്ടാം യോഹന്നാൻ': '2 John',
  'മൂന്നാം യോഹന്നാൻ': '3 John',
  // Malayalam alternate spellings
  'റോമർ': 'Romans',
  'റോമര്‍': 'Romans',
  'ഗലാത്യർ': 'Galatians',
  'എഫെസ്യർ': 'Ephesians',
  'എഫേസ്യർ': 'Ephesians',
  'ഫിലിപ്പിയർ': 'Philippians',
  'കൊലൊസ്സ്യർ': 'Colossians',
  'തെസ്സലൊനീക്യർ': 'Thessalonians',
  '1 തെസ്സലൊനീക്യർ': '1 Thessalonians',
  '2 തെസ്സലൊനീക്യർ': '2 Thessalonians',
  'എബ്രായർ': 'Hebrews',
  '1 യോഹന്നാൻ': '1 John',
  '2 യോഹന്നാൻ': '2 John',
  '3 യോഹന്നാൻ': '3 John',
  '1 പത്രോസ്': '1 Peter',
  '2 പത്രോസ്': '2 Peter',
  'സങ്കീർത്തനം': 'Psalms',
  'സങ്കീര്‍ത്തനം': 'Psalms',
  'സങ്കീർത്തനങ്ങൾ': 'Psalms',
  'ലൂക്കാ': 'Luke',
  'ലൂക്കോസ്': 'Luke',
  'മർക്കോസ്': 'Mark',
  'ജോൺ': 'John',
  // Hindi alternates (variant spellings not in canonical hi-IN list)
  'रोमियो': 'Romans',
  'भजन-संहिता': 'Psalms',
}


// ==================== COMMON INCORRECT MAPPINGS ====================

/**
 * Maps common incorrect book names to their canonical forms.
 * Includes abbreviations, misspellings, and alternative names.
 */
export const INCORRECT_TO_CORRECT: Record<string, Record<string, string>> = {
  'en-US': {
    // Common abbreviations
    'Gen': 'Genesis', 'Ge': 'Genesis', 'Gn': 'Genesis',
    'Ex': 'Exodus', 'Exod': 'Exodus', 'Exo': 'Exodus',
    'Lev': 'Leviticus', 'Le': 'Leviticus', 'Lv': 'Leviticus',
    'Num': 'Numbers', 'Nu': 'Numbers', 'Nm': 'Numbers',
    'Deut': 'Deuteronomy', 'Dt': 'Deuteronomy', 'De': 'Deuteronomy',
    'Josh': 'Joshua', 'Jos': 'Joshua',
    'Judg': 'Judges', 'Jdg': 'Judges', 'Jg': 'Judges',
    'Ru': 'Ruth', 'Rth': 'Ruth',
    '1 Sam': '1 Samuel', '1Sam': '1 Samuel', '1Sa': '1 Samuel', '1 S': '1 Samuel',
    '2 Sam': '2 Samuel', '2Sam': '2 Samuel', '2Sa': '2 Samuel', '2 S': '2 Samuel',
    '1 Kgs': '1 Kings', '1Kgs': '1 Kings', '1Ki': '1 Kings', '1 K': '1 Kings',
    '2 Kgs': '2 Kings', '2Kgs': '2 Kings', '2Ki': '2 Kings', '2 K': '2 Kings',
    '1 Chr': '1 Chronicles', '1Chr': '1 Chronicles', '1Ch': '1 Chronicles',
    '2 Chr': '2 Chronicles', '2Chr': '2 Chronicles', '2Ch': '2 Chronicles',
    'Neh': 'Nehemiah', 'Ne': 'Nehemiah',
    'Est': 'Esther', 'Esth': 'Esther',
    'Ps': 'Psalms', 'Psa': 'Psalms', 'Psalm': 'Psalms', 'Pss': 'Psalms',
    'Prov': 'Proverbs', 'Pr': 'Proverbs', 'Pro': 'Proverbs',
    'Eccl': 'Ecclesiastes', 'Ec': 'Ecclesiastes', 'Ecc': 'Ecclesiastes',
    'Song': 'Song of Solomon', 'SoS': 'Song of Solomon', 'SS': 'Song of Solomon',
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
    // New Testament abbreviations
    'Matt': 'Matthew', 'Mt': 'Matthew',
    'Mk': 'Mark', 'Mr': 'Mark',
    'Lk': 'Luke', 'Luk': 'Luke',
    'Jn': 'John', 'Joh': 'John',
    'Ac': 'Acts',
    'Rom': 'Romans', 'Ro': 'Romans', 'Rm': 'Romans',
    '1 Cor': '1 Corinthians', '1Cor': '1 Corinthians', '1Co': '1 Corinthians',
    '2 Cor': '2 Corinthians', '2Cor': '2 Corinthians', '2Co': '2 Corinthians',
    'Gal': 'Galatians', 'Ga': 'Galatians',
    'Eph': 'Ephesians', 'Ep': 'Ephesians',
    'Phil': 'Philippians', 'Php': 'Philippians', 'Pp': 'Philippians',
    'Col': 'Colossians', 'Co': 'Colossians',
    '1 Thess': '1 Thessalonians', '1Thess': '1 Thessalonians', '1Th': '1 Thessalonians',
    '2 Thess': '2 Thessalonians', '2Thess': '2 Thessalonians', '2Th': '2 Thessalonians',
    '1 Tim': '1 Timothy', '1Tim': '1 Timothy', '1Ti': '1 Timothy',
    '2 Tim': '2 Timothy', '2Tim': '2 Timothy', '2Ti': '2 Timothy',
    'Tit': 'Titus', 'Ti': 'Titus',
    'Phlm': 'Philemon', 'Phm': 'Philemon', 'Pm': 'Philemon',
    'Heb': 'Hebrews', 'He': 'Hebrews',
    'Jas': 'James', 'Jm': 'James',
    '1 Pet': '1 Peter', '1Pet': '1 Peter', '1Pe': '1 Peter', '1P': '1 Peter',
    '2 Pet': '2 Peter', '2Pet': '2 Peter', '2Pe': '2 Peter', '2P': '2 Peter',
    '1 Jn': '1 John', '1Jn': '1 John', '1Jo': '1 John',
    '2 Jn': '2 John', '2Jn': '2 John', '2Jo': '2 John',
    '3 Jn': '3 John', '3Jn': '3 John', '3Jo': '3 John',
    'Jud': 'Jude',
    'Rev': 'Revelation', 'Re': 'Revelation', 'Rv': 'Revelation', 'Revelations': 'Revelation',
    // Common word-based alternatives
    'First Corinthians': '1 Corinthians',
    'Second Corinthians': '2 Corinthians',
    'First Thessalonians': '1 Thessalonians',
    'Second Thessalonians': '2 Thessalonians',
    'First Timothy': '1 Timothy',
    'Second Timothy': '2 Timothy',
    'First Peter': '1 Peter',
    'Second Peter': '2 Peter',
    'First John': '1 John',
    'Second John': '2 John',
    'Third John': '3 John',
    '1st Corinthians': '1 Corinthians',
    '2nd Corinthians': '2 Corinthians',
    '1st Thessalonians': '1 Thessalonians',
    '2nd Thessalonians': '2 Thessalonians',
    '1st Timothy': '1 Timothy',
    '2nd Timothy': '2 Timothy',
    '1st Peter': '1 Peter',
    '2nd Peter': '2 Peter',
    '1st John': '1 John',
    '2nd John': '2 John',
    '3rd John': '3 John',
    'The Gospel of John': 'John',
    'The Gospel of Matthew': 'Matthew',
    'The Gospel of Mark': 'Mark',
    'The Gospel of Luke': 'Luke'
  },
  'hi-IN': {
    // Hindi abbreviations and common misspellings
    // Common book name abbreviations
    'भज': 'भजन संहिता',
    'भजन': 'भजन संहिता',
    'प्रेरितों': 'प्रेरितों के काम',
    // Number format variations (word-based to numeral)
    'पहला शमूएल': '1 शमूएल',
    'दूसरा शमूएल': '2 शमूएल',
    'पहला राजाओं': '1 राजाओं',
    'दूसरा राजाओं': '2 राजाओं',
    'पहला इतिहास': '1 इतिहास',
    'दूसरा इतिहास': '2 इतिहास',
    'पहला कुरिन्थियों': '1 कुरिन्थियों',
    'दूसरा कुरिन्थियों': '2 कुरिन्थियों',
    'पहला थिस्सलुनीकियों': '1 थिस्सलुनीकियों',
    'दूसरा थिस्सलुनीकियों': '2 थिस्सलुनीकियों',
    'पहला तीमुथियुस': '1 तीमुथियुस',
    'दूसरा तीमुथियुस': '2 तीमुथियुस',
    'पहला पतरस': '1 पतरस',
    'दूसरा पतरस': '2 पतरस',
    'पहला यूहन्ना': '1 यूहन्ना',
    'दूसरा यूहन्ना': '2 यूहन्ना',
    'तीसरा यूहन्ना': '3 यूहन्ना',
    // Common misspellings and alternative spellings
    'मर्कुस': 'मरकुस',           // CRITICAL: Common misspelling with halant
    'नहेमायाह': 'नहेम्याह',      // Alternative spelling
    '1 राजा': '1 राजाओं',       // Singular vs plural
    '2 राजा': '2 राजाओं'        // Singular vs plural
  },
  'ml-IN': {
    // Malayalam: Full forms to abbreviated forms (API uses abbreviated forms)
    // Old Testament full forms
    'ഉല്പത്തി': 'ഉല്പ.',
    'പുറപ്പാട്': 'പുറ.',
    'ലേവ്യപുസ്തകം': 'ലേവ്യ.',
    'സംഖ്യാപുസ്തകം': 'സംഖ്യ.',
    'ആവർത്തനം': 'ആവർ.',
    'ആവർത്തനപുസ്തകം': 'ആവർ.',
    'ന്യായാധിപന്മാർ': 'ന്യായാ.',
    '1 ശമൂവേൽ': '1 ശമു.',
    '2 ശമൂവേൽ': '2 ശമു.',
    '1 രാജാക്കന്മാർ': '1 രാജാ.',
    '2 രാജാക്കന്മാർ': '2 രാജാ.',
    '1 ദിനവൃത്താന്തം': '1 ദിന.',
    '2 ദിനവൃത്താന്തം': '2 ദിന.',
    'നെഹെമ്യാവ്': 'നെഹെ.',
    'എസ്ഥേർ': 'എസ്ഥേ.',
    'ഇയ്യോബ്': 'ഇയ്യോ.',
    'സങ്കീർത്തനങ്ങൾ': 'സങ്കീ.',
    'സദൃശവാക്യങ്ങൾ': 'സദൃ.',
    'സഭാപ്രസംഗി': 'സഭാ.',
    'ഉത്തമഗീതം': 'ഉത്ത.',
    'യശായാ': 'യെശ.',
    'യെശയ്യാവ്': 'യെശ.',
    'യിരെമ്യാവ്': 'യിരെ.',
    'വിലാപങ്ങൾ': 'വിലാ.',
    'യെഹെസ്കേൽ': 'യെഹെ.',
    'ദാനിയേൽ': 'ദാനീ.',
    'ഹോശേയ': 'ഹോശേ.',
    'യോവേൽ': 'യോവേ.',
    'ആമോസ്': 'ആമോ.',
    'ഓബദ്യാവ്': 'ഓബ.',
    'ഹബക്കൂക്ക്': 'ഹബ.',
    'സെഫന്യാവ്': 'സെഫ.',
    'ഹഗ്ഗായി': 'ഹഗ്ഗാ.',
    'സെഖര്യാവ്': 'സെഖ.',
    'മലാഖി': 'മലാ.',
    // New Testament full forms
    'മത്തായി': 'മത്താ.',
    'മർക്കൊസ്': 'മർക്കൊ.',
    'ലൂക്കൊസ്': 'ലൂക്കൊ.',
    'യോഹന്നാൻ': 'യോഹ.',
    'അപ്പൊസ്തലപ്രവൃത്തികൾ': 'പ്രവൃത്തികൾ',
    'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ': 'പ്രവൃത്തികൾ',
    'റോമാക്കാർ': 'റോമ.',
    'റോമർ': 'റോമ.',
    '1 കൊരിന്ത്യർ': '1 കൊരി.',
    '2 കൊരിന്ത്യർ': '2 കൊരി.',
    'ഗലാത്യർ': 'ഗലാ.',
    'എഫെസ്യർ': 'എഫെ.',
    'ഫിലിപ്പിയർ': 'ഫിലി.',
    'കൊലൊസ്സ്യർ': 'കൊലൊ.',
    '1 തെസ്സലൊനീക്യർ': '1 തെസ്സ.',
    '2 തെസ്സലൊനീക്യർ': '2 തെസ്സ.',
    '1 തിമൊഥെയൊസ്': '1 തിമൊ.',
    '2 തിമൊഥെയൊസ്': '2 തിമൊ.',
    'തീത്തൊസ്': 'തീത്തൊ.',
    'ഫിലേമോൻ': 'ഫിലേ.',
    'എബ്രായർ': 'എബ്രാ.',
    'യാക്കോബ്': 'യാക്കോ.',
    '1 പത്രൊസ്': '1 പത്രൊ.',
    '2 പത്രൊസ്': '2 പത്രൊ.',
    '1 യോഹന്നാൻ': '1 യോഹ.',
    '2 യോഹന്നാൻ': '2 യോഹ.',
    '3 യോഹന്നാൻ': '3 യോഹ.',
    'വെളിപ്പാട്': 'വെളി.',
    // Number format variations (word-based to numeral)
    'ഒന്നാം ശമൂവേൽ': '1 ശമു.',
    'രണ്ടാം ശമൂവേൽ': '2 ശമു.',
    'ഒന്നാം രാജാക്കന്മാർ': '1 രാജാ.',
    'രണ്ടാം രാജാക്കന്മാർ': '2 രാജാ.',
    'ഒന്നാം കൊരിന്ത്യർ': '1 കൊരി.',
    'രണ്ടാം കൊരിന്ത്യർ': '2 കൊരി.',
    'ഒന്നാം തെസ്സലൊനീക്യർ': '1 തെസ്സ.',
    'രണ്ടാം തെസ്സലൊനീക്യർ': '2 തെസ്സ.',
    'ഒന്നാം തിമൊഥെയൊസ്': '1 തിമൊ.',
    'രണ്ടാം തിമൊഥെയൊസ്': '2 തിമൊ.',
    'ഒന്നാം പത്രൊസ്': '1 പത്രൊ.',
    'രണ്ടാം പത്രൊസ്': '2 പത്രൊ.',
    'ഒന്നാം യോഹന്നാൻ': '1 യോഹ.',
    'രണ്ടാം യോഹന്നാൻ': '2 യോഹ.',
    'മൂന്നാം യോഹന്നാൻ': '3 യോഹ.'
  }
}

// ==================== NORMALIZER CLASS ====================

export interface ValidationResult {
  isValid: boolean
  invalidBooks: string[]
  correctedBooks: Array<{ original: string; corrected: string }>
  warnings: string[]
}

export class BibleBookNormalizer {
  private canonicalBooks: Set<string>
  private incorrectMapping: Record<string, string>
  private languageCode: string

  constructor(languageCode: string = 'en-US') {
    this.languageCode = languageCode

    // Type-safe access to canonical books
    const books = languageCode === 'hi-IN'
      ? CANONICAL_BIBLE_BOOKS['hi-IN']
      : languageCode === 'ml-IN'
      ? CANONICAL_BIBLE_BOOKS['ml-IN']
      : CANONICAL_BIBLE_BOOKS['en-US']

    this.canonicalBooks = new Set(books)

    // Type-safe access to incorrect mappings
    const mappings = languageCode === 'hi-IN'
      ? INCORRECT_TO_CORRECT['hi-IN']
      : languageCode === 'ml-IN'
      ? INCORRECT_TO_CORRECT['ml-IN']
      : INCORRECT_TO_CORRECT['en-US']

    this.incorrectMapping = mappings
  }

  /**
   * Validates Bible book names in text and returns detailed results.
   * Does not modify the text, only analyzes it.
   */
  validateBibleBooks(text: string): ValidationResult {
    const result: ValidationResult = {
      isValid: true,
      invalidBooks: [],
      correctedBooks: [],
      warnings: []
    }

    // Extract potential Bible references with more specific pattern
    // Must start at word boundary or after whitespace to avoid false matches
    // Matches: BookName Chapter:Verse or BookName Chapter
    const referencePattern = /(?:^|\s)([1-3]?\s*[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+(?:\s+[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+)*)\s+(\d+)(?::(\d+))?/g

    let match
    while ((match = referencePattern.exec(text)) !== null) {
      const bookName = match[1].trim()

      // Skip very short potential matches that are likely false positives
      if (bookName.length < 2) {
        continue
      }

      // Check if it's a canonical book name (case-insensitive)
      const isCanonical = Array.from(this.canonicalBooks).some(
        canonical => canonical.toLowerCase() === bookName.toLowerCase()
      )

      if (!isCanonical) {
        // Check if there's a known correction
        const corrected = this.findCorrection(bookName)
        if (corrected) {
          result.correctedBooks.push({ original: bookName, corrected })
          result.warnings.push(`"${bookName}" should be "${corrected}"`)
        } else {
          // Only mark as invalid if it looks like a Bible reference (has numbers after it)
          result.invalidBooks.push(bookName)
          result.isValid = false
        }
      }
    }

    return result
  }

  /**
   * Auto-corrects Bible book names in text.
   * Returns the corrected text with all book names normalized.
   * Only corrects when book name is followed by chapter:verse pattern.
   */
  normalizeBibleBooks(text: string): string {
    let correctedText = text

    // Create a map of all potential book names (both incorrect and canonical)
    const allBookNames = new Map<string, string>()

    // Add incorrect mappings
    for (const [incorrect, correct] of Object.entries(this.incorrectMapping)) {
      allBookNames.set(incorrect.toLowerCase(), correct)
    }

    // Add canonical books (for case normalization)
    for (const canonical of this.canonicalBooks) {
      allBookNames.set(canonical.toLowerCase(), canonical)
    }

    // Find and replace Bible references (book name + chapter:verse)
    // This is more conservative and avoids false positives
    const referencePattern = /\b([1-3]?\s*[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+(?:\s+[A-Za-z\u0900-\u097F\u0D00-\u0D7F]+){0,4})\s+(\d+)(?::(\d+)(?:-(\d+))?)?/g

    correctedText = correctedText.replace(referencePattern, (match, bookName, chapter, startVerse, endVerse) => {
      const normalizedBook = allBookNames.get(bookName.trim().toLowerCase())

      if (normalizedBook) {
        // Reconstruct the reference with corrected book name
        let result = normalizedBook + ' ' + chapter
        if (startVerse) {
          result += ':' + startVerse
          if (endVerse) {
            result += '-' + endVerse
          }
        }
        return result
      }

      // No correction found, return original
      return match
    })

    return correctedText
  }

  /**
   * Finds the correct book name for a given incorrect/abbreviated name.
   * Returns null if no correction is found.
   */
  private findCorrection(bookName: string): string | null {
    // Direct lookup in incorrect mapping (case-insensitive)
    for (const [incorrect, correct] of Object.entries(this.incorrectMapping)) {
      if (incorrect.toLowerCase() === bookName.toLowerCase()) {
        return correct
      }
    }

    // Fuzzy match against canonical books
    const lowerBook = bookName.toLowerCase()
    for (const canonical of this.canonicalBooks) {
      if (canonical.toLowerCase() === lowerBook) {
        return canonical
      }
    }

    return null
  }

  /**
   * Extracts scripture references from text using canonical Bible book names.
   * Searches for known book names followed by chapter or chapter:verse pattern.
   * Supports both canonical and abbreviated book names (e.g., "Psalm" or "Psalms").
   * Supports both formats:
   * - Chapter only: "Psalm 23", "भजन संहिता 23"
   * - Chapter:Verse: "John 3:16", "भजन संहिता 23:1"
   * - Verse range: "John 3:16-17", "भजन संहिता 23:1-6"
   *
   * @param text - Text to extract scripture references from
   * @returns Array of unique scripture references (normalized to canonical book names)
   *
   * @example
   * ```typescript
   * const normalizer = new BibleBookNormalizer('en-US')
   * const refs = normalizer.extractScriptureReferences('See Psalm 23 and Jn 3:16')
   * // Returns: ['Psalms 23', 'John 3:16'] (normalized)
   * ```
   */
  extractScriptureReferences(text: string): string[] {
    const results: string[] = []

    // Build a complete list of all book names (both canonical and incorrect/abbreviated)
    const allBookNames = new Set<string>()

    // Add canonical books
    for (const book of this.canonicalBooks) {
      allBookNames.add(book)
    }

    // Add incorrect/abbreviated book names
    for (const incorrectName of Object.keys(this.incorrectMapping)) {
      allBookNames.add(incorrectName)
    }

    // Sort by length descending to match longer names first (e.g., "भजन संहिता" before "भजन")
    const sortedBooks = Array.from(allBookNames).sort((a, b) => b.length - a.length)

    // Create pattern: (book_name)\s+(\d+)(?::(\d+)(?:-(\d+))?)?
    // Supports:
    // - Book Chapter: "Psalm 23"
    // - Book Chapter:Verse: "John 3:16"
    // - Book Chapter:Verse-Verse: "John 3:16-17"
    const booksPattern = sortedBooks.map(book => this.escapeRegex(book)).join('|')
    const pattern = new RegExp(`(${booksPattern})\\s+(\\d+)(?::(\\d+)(?:-(\\d+))?)?`, 'gi')

    let match
    while ((match = pattern.exec(text)) !== null) {
      // Normalize the book name to its canonical form
      const bookName = match[1]
      const bookKey = bookName.toLowerCase() // Normalize for case-insensitive lookups
      const chapter = match[2]
      const verse = match[3]
      const endVerse = match[4]

      // Find canonical name (check incorrect mapping first with case-insensitive lookup, then canonical)
      // Look up in incorrectMapping using case-insensitive comparison
      let canonicalBook: string | undefined
      for (const [incorrect, correct] of Object.entries(this.incorrectMapping)) {
        if (incorrect.toLowerCase() === bookKey) {
          canonicalBook = correct
          break
        }
      }
      // If not found in incorrectMapping, try canonical books with case-insensitive comparison
      if (!canonicalBook) {
        canonicalBook = Array.from(this.canonicalBooks).find(
          b => b.toLowerCase() === bookKey
        )
      }
      // Fallback to original book name if no match found
      canonicalBook = canonicalBook || bookName

      // Reconstruct reference with canonical book name
      let ref = `${canonicalBook} ${chapter}`
      if (verse) {
        ref += `:${verse}`
        if (endVerse) {
          ref += `-${endVerse}`
        }
      }

      results.push(ref)
    }

    return [...new Set(results)]
  }

  /**
   * Escapes special regex characters in a string.
   */
  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  }

  /**
   * Logs validation warnings to console (for monitoring).
   */
  logValidationWarnings(validation: ValidationResult, conversationId: string): void {
    if (!validation.isValid || validation.warnings.length > 0) {
      console.warn(`[BibleBookNormalizer] Validation issues in conversation ${conversationId}:`, {
        invalidBooks: validation.invalidBooks,
        corrections: validation.correctedBooks,
        warnings: validation.warnings
      })
    }
  }
}
