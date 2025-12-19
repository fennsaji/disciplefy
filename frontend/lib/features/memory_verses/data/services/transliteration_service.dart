import 'dart:math';

/// Service for converting Devanagari (Hindi) and Malayalam scripts
/// to romanized (Latin) text for pronunciation hints.
///
/// This service provides transliteration (not translation) - converting
/// the phonetic sounds of Hindi/Malayalam text into Roman characters.
///
/// Example:
/// - Hindi: "मैं सब कुछ कर सकता हूँ" → "main sab kuch kar sakta hoon"
/// - Malayalam: "എനിക്ക് സകലവും ചെയ്യാൻ കഴിയും" → "enikku sakalavum cheyyaan kazhiyum"
class TransliterationService {
  /// Transliterates text from Hindi or Malayalam to Roman script.
  ///
  /// Returns null for English text (no transliteration needed).
  /// Returns the romanized version for Hindi (hi) or Malayalam (ml).
  static String? transliterate(String text, String languageCode) {
    if (languageCode == 'en') return null;
    if (languageCode == 'hi') return _transliterateDevanagari(text);
    if (languageCode == 'ml') return _transliterateMalayalam(text);
    return null;
  }

  /// Detects the language of the given text based on Unicode ranges.
  ///
  /// Returns 'hi' for Hindi (Devanagari script), 'ml' for Malayalam, 'en' for English.
  static String detectLanguage(String text) {
    // Check for Devanagari characters (Hindi) - Unicode range: 0900-097F
    final devanagariPattern = RegExp(r'[\u0900-\u097F]');
    if (devanagariPattern.hasMatch(text)) return 'hi';

    // Check for Malayalam characters - Unicode range: 0D00-0D7F
    final malayalamPattern = RegExp(r'[\u0D00-\u0D7F]');
    if (malayalamPattern.hasMatch(text)) return 'ml';

    // Default to English
    return 'en';
  }

  /// Transliterates Devanagari (Hindi) text to Roman script.
  /// Applies schwa deletion rules for natural Hinglish output.
  static String _transliterateDevanagari(String text) {
    final buffer = StringBuffer();
    final chars = text.split('');

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final nextChar = i + 1 < chars.length ? chars[i + 1] : '';

      // Check if it's a Devanagari character
      if (_devanagariConsonants.containsKey(char)) {
        // It's a consonant
        String romanized = _devanagariConsonants[char]!;

        // Check if followed by halant (virama) - removes inherent 'a'
        if (nextChar == '्') {
          // Remove the trailing 'a' if present
          if (romanized.endsWith('a') && romanized.length > 1) {
            romanized = romanized.substring(0, romanized.length - 1);
          }
          i++; // Skip the halant
        }
        // Check if followed by a matra (vowel sign)
        else if (_devanagariMatras.containsKey(nextChar)) {
          // Replace the inherent 'a' with the matra vowel
          if (romanized.endsWith('a') && romanized.length > 1) {
            romanized = romanized.substring(0, romanized.length - 1);
          }
          romanized += _devanagariMatras[nextChar]!;
          i++; // Skip the matra
        }

        buffer.write(romanized);
      } else if (_devanagariVowels.containsKey(char)) {
        // Standalone vowel
        buffer.write(_devanagariVowels[char]);
      } else if (_devanagariMatras.containsKey(char)) {
        // Matra without preceding consonant (shouldn't happen normally)
        buffer.write(_devanagariMatras[char]);
      } else if (_devanagariNumerals.containsKey(char)) {
        // Devanagari numeral
        buffer.write(_devanagariNumerals[char]);
      } else if (char == '्') {
        // Halant by itself - skip
        continue;
      } else if (char == '।' || char == '॥') {
        // Skip Hindi punctuation (danda)
        continue;
      } else {
        // Pass through spaces, punctuation, etc.
        buffer.write(char);
      }
    }

    // Apply natural Hinglish simplifications in order:
    // 1. Cluster simplifications (thya→th, etc.)
    // 2. Schwa deletion (remove trailing single 'a' from inherent vowels)
    // 3. Simplify long vowels (aa→a, ii→i, uu→u) - AFTER schwa deletion
    // 4. Word-specific corrections
    String result = buffer.toString().trim();
    result = _applyClusterSimplifications(result);
    result = _applySchwaDeltion(result);
    result = _simplifyLongVowels(result); // Convert aa→a, ii→i, uu→u
    result = _applyWordSimplifications(result);
    return result;
  }

  /// Applies schwa deletion rules to romanized Hindi text.
  /// Removes trailing 'a' from words (except single-letter words and some exceptions).
  static String _applySchwaDeltion(String text) {
    final words = text.split(' ');
    final result = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;

      // Don't modify single-character words or very short words
      if (word.length <= 2) {
        result.add(word);
        continue;
      }

      // Words that should keep their final 'a'
      // (common words ending in long 'a' sound that people type with 'a')
      final keepFinalA = {
        'kya',
        'hoga',
        'jata',
        'ata',
        'karta',
        'hota',
        'leta',
        'deta',
        'jaga',
        'raja',
        'pita',
        'mata',
        'beta',
        'data',
        'gata',
      };

      if (keepFinalA.contains(word.toLowerCase())) {
        result.add(word);
        continue;
      }

      // Remove trailing 'a' if word ends with 'a' and has more content
      // but keep it if the word ends in 'aa', 'ia', 'ua', 'ea', 'oa' (vowel clusters)
      if (word.endsWith('a') && word.length > 2) {
        final beforeLast = word[word.length - 2];
        // Check if it's a vowel cluster - don't remove 'a' in these cases
        if ('aeiou'.contains(beforeLast)) {
          result.add(word);
        } else {
          // Remove the trailing 'a' (schwa deletion)
          result.add(word.substring(0, word.length - 1));
        }
      } else {
        result.add(word);
      }
    }

    return result.join(' ');
  }

  /// Simplifies long vowel markers to natural Hinglish spelling.
  /// This runs AFTER schwa deletion to preserve the distinction.
  /// Example: "meraa" → "mera", "yahowaa" → "yahowa"
  static String _simplifyLongVowels(String text) {
    return text
        .replaceAll('aa', 'a') // आ/ा → 'a' (not 'aa')
        .replaceAll('ii', 'i') // ई/ी → 'i' (not 'ii' or 'ee')
        .replaceAll('uu', 'u'); // ऊ/ू → 'u' (not 'uu' or 'oo')
  }

  /// Simplifies common consonant clusters that are pronounced differently
  /// in natural Hinglish typing.
  static String _applyClusterSimplifications(String text) {
    String result = text;

    // Common cluster simplifications based on how people actually type
    final clusterReplacements = {
      // Word-ending clusters
      'thya': 'th', // सामर्थ्य → samarth
      'tya': 't', // सत्य → sat
      'dya': 'd', // विद्या → vidya (keep this common word as is)
      'ksha': 'ksh', // रक्षा → raksha (often typed as raksh)
      'gya': 'gy', // ज्ञान → gyan
      'shya': 'sh', // common simplification

      // Gemination simplifications (double consonants often typed single)
      'kka': 'ka',
      'tta': 'ta',
      'ppa': 'pa',
      'mma': 'ma',
      'nna': 'na',
      'lla': 'la',
      'chcha': 'cha',

      // Common sound simplifications
      'aai': 'ai', // आई → ai not aai
      'oou': 'ou', // Double vowel fix
    };

    clusterReplacements.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    return result;
  }

  /// Applies word-level simplifications for common Hindi words
  /// that have established Hinglish spellings different from transliteration.
  static String _applyWordSimplifications(String text) {
    final words = text.split(' ');
    final result = <String>[];

    // Map of transliterated forms to natural Hinglish
    final wordReplacements = {
      // Pronouns and common words
      'main': 'mein', // मैं - commonly typed as 'mein'
      'hun': 'hoon', // हूँ - commonly typed as 'hoon' or 'hun'
      'hain': 'hain', // हैं - keep as is
      'hai': 'hai', // है - keep as is
      'usamen': 'usme', // उसमें - commonly typed as 'usme'
      'usme': 'usme', // keep
      'jisamen': 'jisme', // जिसमें
      'kisamen': 'kisme', // किसमें
      'yahaan': 'yahan', // यहाँ
      'vahaan': 'wahan', // वहाँ
      'kahan': 'kahan', // कहाँ - keep

      // Verb forms
      'kara': 'kar', // कर
      'sakata': 'sakta', // सकता
      'sakataa': 'sakta',
      'hota': 'hota', // keep - commonly used
      'karta': 'karta', // keep
      'deta': 'deta', // keep

      // Common nouns
      'saba': 'sab', // सब
      'kuchha': 'kuch', // कुछ
      'kuchh': 'kuch',
      'bhagavaan': 'bhagwan', // भगवान
      'ishu': 'yeshu', // ईशु/यीशु
      'yishu': 'yeshu',
      'masih': 'masih', // keep
      'prabhu': 'prabhu', // keep

      // Question words
      'kyaa': 'kya', // क्या
      'kaisaa': 'kaisa', // कैसा
      'kaun': 'kaun', // keep

      // Prepositions and connectors
      'aur': 'aur', // और - keep
      'par': 'par', // पर - keep
      'ko': 'ko', // को - keep
      'se': 'se', // से - keep
      'men': 'mein', // में - commonly 'mein'
      'ke': 'ke', // के - keep
      'ki': 'ki', // की - keep
      'ka': 'ka', // का - keep
    };

    for (final word in words) {
      final lower = word.toLowerCase();
      if (wordReplacements.containsKey(lower)) {
        result.add(wordReplacements[lower]!);
      } else {
        result.add(word);
      }
    }

    return result.join(' ');
  }

  /// Transliterates Malayalam text to Roman script.
  static String _transliterateMalayalam(String text) {
    final buffer = StringBuffer();
    final chars = text.split('');

    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final nextChar = i + 1 < chars.length ? chars[i + 1] : '';

      // Check if it's a Malayalam character
      if (_malayalamConsonants.containsKey(char)) {
        // It's a consonant
        String romanized = _malayalamConsonants[char]!;

        // Check if followed by chandrakkala (virama) - removes inherent 'a'
        if (nextChar == '്') {
          // Remove the trailing 'a' if present
          if (romanized.endsWith('a') && romanized.length > 1) {
            romanized = romanized.substring(0, romanized.length - 1);
          }
          i++; // Skip the chandrakkala
        }
        // Check if followed by a matra (vowel sign)
        else if (_malayalamMatras.containsKey(nextChar)) {
          // Replace the inherent 'a' with the matra vowel
          if (romanized.endsWith('a') && romanized.length > 1) {
            romanized = romanized.substring(0, romanized.length - 1);
          }
          romanized += _malayalamMatras[nextChar]!;
          i++; // Skip the matra
        }

        buffer.write(romanized);
      } else if (_malayalamVowels.containsKey(char)) {
        // Standalone vowel
        buffer.write(_malayalamVowels[char]);
      } else if (_malayalamMatras.containsKey(char)) {
        // Matra without preceding consonant
        buffer.write(_malayalamMatras[char]);
      } else if (_malayalamChillus.containsKey(char)) {
        // Chillu (pure consonant)
        buffer.write(_malayalamChillus[char]);
      } else if (char == '്') {
        // Chandrakkala by itself - skip
        continue;
      } else {
        // Pass through spaces, punctuation, etc.
        buffer.write(char);
      }
    }

    return buffer.toString().trim();
  }

  // ==================== Hindi (Devanagari) Character Maps ====================
  // NOTE: These mappings use simplified/natural Hinglish spellings that match
  // how people actually type, not strict transliteration.

  /// Devanagari standalone vowels
  /// NOTE: Long vowels use doubled letters to preserve through schwa deletion
  static const Map<String, String> _devanagariVowels = {
    'अ': 'a',
    'आ': 'aa', // Long 'a' - keep as 'aa', simplified after schwa deletion
    'इ': 'i',
    'ई': 'ii', // Long 'i' - keep as 'ii'
    'उ': 'u',
    'ऊ': 'uu', // Long 'u' - keep as 'uu'
    'ऋ': 'ri',
    'ए': 'e',
    'ऐ': 'ai',
    'ओ': 'o',
    'औ': 'au',
    'अं': 'an',
    'अः': 'ah',
  };

  /// Devanagari vowel matras (signs attached to consonants)
  /// NOTE: Long vowels use doubled letters (aa, ii, uu) during transliteration
  /// to distinguish from inherent schwa. They get simplified AFTER schwa deletion.
  static const Map<String, String> _devanagariMatras = {
    'ा': 'aa', // Long 'a' - keep as 'aa' to preserve through schwa deletion
    'ि': 'i',
    'ी': 'ii', // Long 'i' - keep as 'ii' to distinguish
    'ु': 'u',
    'ू': 'uu', // Long 'u' - keep as 'uu' to distinguish
    'ृ': 'ri',
    'े': 'e',
    'ै': 'ai',
    'ो': 'o',
    'ौ': 'au',
    'ं': 'n', // Anusvara (e.g., "main" not "mai")
    'ः': '', // Visarga - often silent in common words
    'ँ': 'n', // Chandrabindu (nasalization)
  };

  /// Devanagari consonants (with inherent 'a' vowel)
  static const Map<String, String> _devanagariConsonants = {
    // Velars
    'क': 'ka',
    'ख': 'kha',
    'ग': 'ga',
    'घ': 'gha',
    'ङ': 'nga',
    // Palatals
    'च': 'cha',
    'छ': 'chha',
    'ज': 'ja',
    'झ': 'jha',
    'ञ': 'nya',
    // Retroflexes
    'ट': 'ta',
    'ठ': 'tha',
    'ड': 'da',
    'ढ': 'dha',
    'ण': 'na',
    // Dentals
    'त': 'ta',
    'थ': 'tha',
    'द': 'da',
    'ध': 'dha',
    'न': 'na',
    // Labials
    'प': 'pa',
    'फ': 'pha',
    'ब': 'ba',
    'भ': 'bha',
    'म': 'ma',
    // Semi-vowels
    'य': 'ya',
    'र': 'ra',
    'ल': 'la',
    'व': 'va',
    // Sibilants
    'श': 'sha',
    'ष': 'sha',
    'स': 'sa',
    // Aspirate
    'ह': 'ha',
    // Nukta variants (for Persian/Arabic loan words)
    'क़': 'qa',
    'ख़': 'kha',
    'ग़': 'gha',
    'ज़': 'za',
    'ड़': 'da',
    'ढ़': 'dha',
    'फ़': 'fa',
  };

  /// Devanagari numerals
  static const Map<String, String> _devanagariNumerals = {
    '०': '0',
    '१': '1',
    '२': '2',
    '३': '3',
    '४': '4',
    '५': '5',
    '६': '6',
    '७': '7',
    '८': '8',
    '९': '9',
  };

  // ==================== Malayalam Character Maps ====================
  // NOTE: Using simplified/natural Manglish spellings

  /// Malayalam standalone vowels
  static const Map<String, String> _malayalamVowels = {
    'അ': 'a',
    'ആ': 'a', // Simplified: 'aa' → 'a'
    'ഇ': 'i',
    'ഈ': 'i', // Simplified: 'ee' → 'i'
    'ഉ': 'u',
    'ഊ': 'u', // Simplified: 'oo' → 'u'
    'ഋ': 'ri',
    'എ': 'e',
    'ഏ': 'e', // Simplified
    'ഐ': 'ai',
    'ഒ': 'o',
    'ഓ': 'o', // Simplified: 'oo' → 'o'
    'ഔ': 'au',
  };

  /// Malayalam vowel matras (signs attached to consonants)
  /// Using natural Manglish spellings
  static const Map<String, String> _malayalamMatras = {
    'ാ': 'a', // Simplified: 'aa' → 'a'
    'ി': 'i',
    'ീ': 'i', // Simplified: 'ee' → 'i'
    'ു': 'u',
    'ൂ': 'u', // Simplified: 'oo' → 'u'
    'ൃ': 'ri',
    'െ': 'e',
    'േ': 'e', // Simplified
    'ൈ': 'ai',
    'ൊ': 'o',
    'ോ': 'o', // Simplified
    'ൌ': 'au',
    'ം': 'm', // Anusvara
    'ഃ': '', // Visarga - often silent
  };

  /// Malayalam consonants (with inherent 'a' vowel)
  static const Map<String, String> _malayalamConsonants = {
    // Velars
    'ക': 'ka',
    'ഖ': 'kha',
    'ഗ': 'ga',
    'ഘ': 'gha',
    'ങ': 'nga',
    // Palatals
    'ച': 'cha',
    'ഛ': 'chha',
    'ജ': 'ja',
    'ഝ': 'jha',
    'ഞ': 'nya',
    // Retroflexes
    'ട': 'ta',
    'ഠ': 'tha',
    'ഡ': 'da',
    'ഢ': 'dha',
    'ണ': 'na',
    // Dentals
    'ത': 'tha',
    'ഥ': 'thha',
    'ദ': 'da',
    'ധ': 'dha',
    'ന': 'na',
    // Labials
    'പ': 'pa',
    'ഫ': 'pha',
    'ബ': 'ba',
    'ഭ': 'bha',
    'മ': 'ma',
    // Semi-vowels
    'യ': 'ya',
    'ര': 'ra',
    'ല': 'la',
    'വ': 'va',
    // Sibilants
    'ശ': 'sha',
    'ഷ': 'sha',
    'സ': 'sa',
    // Aspirate
    'ഹ': 'ha',
    // Malayalam specific
    'ള': 'la',
    'ഴ': 'zha',
    'റ': 'ra',
  };

  /// Malayalam chillu characters (pure consonants without vowel)
  static const Map<String, String> _malayalamChillus = {
    'ൺ': 'n',
    'ൻ': 'n',
    'ർ': 'r',
    'ൽ': 'l',
    'ൾ': 'l',
    'ൿ': 'k',
  };

  // ==================== Text Comparison Functions ====================

  /// Calculates accuracy percentage between user input and expected text
  /// using Levenshtein distance algorithm.
  ///
  /// Returns a value between 0.0 and 100.0, where 100.0 is a perfect match.
  /// Text is normalized before comparison (lowercase, trimmed, punctuation removed).
  static double calculateAccuracy(String userInput, String expected) {
    final normalizedInput = _normalize(userInput);
    final normalizedExpected = _normalize(expected);

    if (normalizedExpected.isEmpty) return 100.0;
    if (normalizedInput.isEmpty) return 0.0;

    final distance = _levenshteinDistance(normalizedInput, normalizedExpected);
    final maxLength = max(normalizedInput.length, normalizedExpected.length);

    final similarity = 1.0 - (distance / maxLength);
    return (similarity * 100).clamp(0.0, 100.0);
  }

  /// Normalizes text for comparison: lowercase, trim, single spaces, no punctuation,
  /// and applies Hinglish variant normalization.
  static String _normalize(String text) {
    String result = text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ''); // Remove punctuation

    // Apply Hinglish variant normalization for fairer comparison
    result = _normalizeHinglishVariants(result);
    return result;
  }

  /// Normalizes common Hinglish spelling variants to a canonical form.
  /// This makes comparison fairer since Hinglish has no standard spelling.
  /// Both user input and expected text go through this normalization.
  static String _normalizeHinglishVariants(String text) {
    // Map of variant spellings to canonical form
    // The canonical form is arbitrary - we just need consistency
    final variants = {
      // Common pronouns and words with ee/i, oo/u, aa/a variations
      'mein': 'main',
      'mai': 'main',
      'hoon': 'hun',
      'hoo': 'hu',
      'mujhe': 'mujhe',
      'mujhey': 'mujhe',

      // Verb forms
      'sakta': 'sakta',
      'saktaa': 'sakta',
      'saktha': 'sakta',
      'karta': 'karta',
      'kartaa': 'karta',
      'kartha': 'karta',
      'deta': 'deta',
      'detaa': 'deta',
      'detha': 'deta',
      'hota': 'hota',
      'hotaa': 'hota',
      'hotha': 'hota',

      // Common locative forms
      'usme': 'usme',
      'usmein': 'usme',
      'usmai': 'usme',
      'jisme': 'jisme',
      'jismein': 'jisme',
      'jismai': 'jisme',

      // Common nouns/pronouns
      'kuch': 'kuch',
      'kuchh': 'kuch',
      'sab': 'sab',
      'sub': 'sab',

      // Long vowel variations
      'hai': 'hai',
      'hae': 'hai',
      'hey': 'hai',
      'hain': 'hain',
      'hayn': 'hain',

      // Common words
      'jo': 'jo',
      'joh': 'jo',
      'kar': 'kar',
      'krr': 'kar',

      // Christ/Christian terms
      'masih': 'masih',
      'maseeh': 'masih',
      'yeshu': 'yeshu',
      'ishu': 'yeshu',
      'yesu': 'yeshu',

      // God names
      'yahova': 'yahova',
      'yahowa': 'yahova',
      'yahowah': 'yahova',
      'yahovah': 'yahova',
      'yehova': 'yahova',

      // Common words with v/w variation
      'charwaha': 'charvaha',
      'charavaha': 'charvaha',
      'charvaha': 'charvaha',
    };

    final words = text.split(' ');
    final result = <String>[];

    for (final word in words) {
      if (variants.containsKey(word)) {
        result.add(variants[word]!);
      } else {
        result.add(word);
      }
    }

    return result.join(' ');
  }

  /// Calculates the Levenshtein (edit) distance between two strings.
  ///
  /// The Levenshtein distance is the minimum number of single-character edits
  /// (insertions, deletions, or substitutions) required to transform one string
  /// into the other.
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Create a 2D matrix
    final List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    // Initialize first column (deletions)
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }

    // Initialize first row (insertions)
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // Fill in the rest of the matrix
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }
}
