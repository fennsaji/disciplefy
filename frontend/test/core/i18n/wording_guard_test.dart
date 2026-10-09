import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_en.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_hi.dart';
import 'package:disciplefy_bible_study/core/i18n/translations_ml.dart';

Iterable<MapEntry<String, String>> flatten(Map<String, dynamic> m,
    [String p = '']) sync* {
  for (final e in m.entries) {
    final k = p.isEmpty ? e.key : '$p.${e.key}';
    if (e.value is Map<String, dynamic>) {
      yield* flatten(e.value as Map<String, dynamic>, k);
    } else if (e.value is String) {
      yield MapEntry(k, e.value as String);
    }
  }
}

/// Namespaces shown to new users. Later phases add theirs here.
const guardedNamespaces = [
  'home',
  'home_today',
  'learning_paths',
  'lesson',
  'generate_simple',
  'credits',
  'plan',
  'tokens',
  'first_run',
  'account',
  'nfy',
  'intro',
  'topics',
  'all_paths',
  'memory',
  'settings',
  'study_topics',
  'learning_path',
  'memory_champions',
  'memory_home',
  'memory_nav',
  'disciple_level',
  'community_lessons',
  'continue_learning',
];

/// Known exceptions.
/// - `learning_paths.xp` is the unit after a path's XP total on the path card
///   and the fellowship path picker, and `community_lessons.xp_earned` is a
///   member's XP on a fellowship lesson; both go once their widgets stop
///   showing XP (widget change, not wording).
/// - The delete-account and reset-progress warnings must say what is lost.
const allowedXpKeys = {
  'learning_paths.xp',
  'community_lessons.xp_earned',
  'settings.delete_account_lose_progress',
  'study_topics.reset_item_xp',
};

/// Keys that name path items; these must say "lesson", never "topic".
const pathItemKeys = [
  'learning_paths.',
  'learning_path.',
  'home.',
  'study_topics.',
  'continue_learning.',
  'settings.',
];

/// Placeholders such as `{tokens}` are not user-visible words.
String _visible(String v) => v.replaceAll(RegExp(r'\{[^}]*\}'), '');

void main() {
  bool guarded(String k) => guardedNamespaces.any((n) => k.startsWith('$n.'));

  test(
      'English: credits not tokens, lessons not topics in paths, '
      'no XP on new-user surfaces, no "AI"', () {
    final bad = <String>[];
    for (final e in flatten(englishTranslations).where((e) => guarded(e.key))) {
      final v = _visible(e.value);
      if (RegExp(r'\btokens?\b', caseSensitive: false).hasMatch(v)) {
        bad.add('${e.key}: token');
      }
      if (RegExp(r'\bXP\b').hasMatch(v) &&
          !e.key.contains('leaderboard') &&
          !allowedXpKeys.contains(e.key)) {
        bad.add('${e.key}: XP');
      }
      if (RegExp(r'\bAI\b').hasMatch(v)) bad.add('${e.key}: AI');
      if (RegExp(r'\bSeekers?\b').hasMatch(v)) bad.add('${e.key}: Seeker');
    }
    for (final e in flatten(englishTranslations)
        .where((e) => pathItemKeys.any(e.key.startsWith))) {
      if (RegExp(r'\btopics?\b', caseSensitive: false)
          .hasMatch(_visible(e.value))) {
        bad.add('${e.key}: topic');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('one name for the Standard study mode: never "Full guide"', () {
    // Owner rule: the depth is "Standard" everywhere (chips, switches,
    // hints, intro copy), and Quick Read is always cased as its mode name.
    final banned = {
      'en': [
        RegExp(r'\bfull guide\b', caseSensitive: false),
        RegExp(r'\bQuick read\b'),
      ],
      'hi': [RegExp('पूरी गाइड'), RegExp('पूरा गाइड')],
      'ml': [RegExp('പൂർണ ഗൈഡ'), RegExp('പൂർണ്ണ ഗൈഡ')],
    };
    final maps = {
      'en': englishTranslations,
      'hi': hindiTranslations,
      'ml': malayalamTranslations,
    };
    final bad = [
      for (final lang in maps.keys)
        for (final e in flatten(maps[lang]!))
          if (banned[lang]!.any((r) => r.hasMatch(_visible(e.value))))
            '$lang ${e.key}: ${e.value}',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('no "AI" in any user copy, in any language', () {
    final bad = [
      for (final m in [
        englishTranslations,
        hindiTranslations,
        malayalamTranslations,
      ])
        ...flatten(m)
            .where((e) => RegExp(r'\bAI\b').hasMatch(_visible(e.value)))
            .map((e) => e.key),
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Hindi uses simple everyday terms, not transliterations', () {
    // Owner rule: simple everyday Hindi over transliteration; transliterate
    // only when the Hindi word is literary or unclear.
    const oldTerms = [
      'स्मरण वचन',
      'याद वर्सेज',
      'स्मृति आयत',
      'स्मृति वचन',
      'स्मरण पद',
      'याद आयत',
      'मेमोरी डेक',
      'लर्निंग',
      'पाथ',
      'पथ',
      'सीखने के मार्ग',
      'स्टडी',
      'मार्गदर्शिका',
      'क्विक',
      'डीप डाइव',
      'फॉलो-अप',
      // Quick read is छोटी पढ़ाई (chip: छोटी); लघु is bookish.
      'लघु',
      'डेली',
      'बेस्ट',
      'लीडर्स',
      'फीचर',
      'असाइन',
      'यूज़र्स',
      'यूज ',
      'लिमिट',
      'हिस्ट्री',
      'स्टैटिस्टिक्स',
      'प्राइवेसी',
      'कैंसल',
      'डिलीट',
      'स्मृति',
      'डिसाइपल',
    ];
    final values = flatten(hindiTranslations).map((e) => e.value);
    final bad = [
      for (final v in values)
        for (final t in oldTerms)
          if (v.contains(t)) '$t: $v',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
    // "लगातार दिन" is not a noun; counts read "लगातार {n} दिन" and the noun
    // stays स्ट्रीक.
    expect(values.where((v) => v.contains('लगातार दिन')), isEmpty);
    // Save is सहेजें, not सेव करें (सेवा "service" is fine).
    expect(values.where((v) => RegExp('सेव(?![ाक])').hasMatch(v)), isEmpty);
  });

  test('path items are lessons (पाठ / പാഠം), never topics, in hi and ml', () {
    final bad = <String>[
      for (final e in flatten(hindiTranslations)
          .where((e) => pathItemKeys.any(e.key.startsWith)))
        if (_visible(e.value).contains('विषय')) e.key,
      for (final e in flatten(malayalamTranslations)
          .where((e) => pathItemKeys.any(e.key.startsWith)))
        if (_visible(e.value).contains('വിഷയ')) e.key,
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Malayalam uses simple everyday words, not transliterations', () {
    // Owner rule: common English words people use (ക്രെഡിറ്റ്, പ്ലാൻ, സേവ്,
    // ഗൈഡ്, പെൻഡിംഗ്, Discipler) are fine; otherwise plain Malayalam. A streak is
    // തുടർച്ച; the study modes are വേഗ വായന / സാധാരണ / ആഴത്തിലുള്ള പഠനം.
    const oldTerms = [
      'സ്റ്റ്രീ',
      'സ്ട്രീ',
      'ക്വിക്ക്',
      'ഡീപ്പ്',
      'സ്റ്റഡി',
      'ഫോളോ',
      'ലേണിംഗ്',
      'പാത്ത്',
      'ഡെയ്ലി',
      'യൂസേഴ്',
      'യൂസർമാ',
      'ലീഡർസ',
      'ഫീച്ചർ',
      'ലിമിറ്റ്',
      'അൺലിമിറ്റഡ്',
      'കറന്റ്',
      'ഹിസ്റ്ററി',
      'സ്റ്റാറ്റിസ്റ്റിക്സ്',
      'പ്രാക്ടീസ്',
      'ഡിലീറ്റ്',
      'കാൻസൽ',
      'ഡിസൈപ്പിൾ',
      // Garbled words (Hindi loans) from an old machine pass.
      'പ്രാതമ്യം',
      'പ്രാപ്തരുകൾ',
      'ലാഗൂ',
      'സുധാരണ',
      'വേണംഎന്നാലും',
      // Malayalam ends sentences with a full stop, not the Hindi danda.
      '।',
    ];
    final values = flatten(malayalamTranslations).map((e) => e.value);
    final bad = [
      for (final v in values)
        for (final t in oldTerms)
          if (v.contains(t)) '$t: $v',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('Malayalam uses one memory-verse term (മനഃപാഠ വാക്യം)', () {
    const oldTerms = [
      'സ്മരണ വാക്യ',
      'മെമ്മറി വേഴ്',
      'മെമ്മറി വെർസ',
      'മെമ്മറി വചന',
      'മെമ്മറി വാക്യ',
      'മെമ്മറി ഡെക്ക',
      'ഓർമ്മ വാക്യ',
      'ഓർമ്മ വചന',
      'മനഃപാഠ വചന',
    ];
    final values = flatten(malayalamTranslations).map((e) => e.value);
    expect(values.where((v) => oldTerms.any(v.contains)), isEmpty);
  });

  test('the daily verse is वचन / വചനം, never आयत or ദൈനിക', () {
    final hi = flatten(hindiTranslations).map((e) => e.value);
    final ml = flatten(malayalamTranslations).map((e) => e.value);
    expect(hi.where((v) => v.contains('दैनिक आयत') || v.contains('दिन की आयत')),
        isEmpty);
    expect(
        ml.where((v) => v.contains('ദൈനിക വചന') || v.contains('ദിവസത്തെ വചന')),
        isEmpty);
  });

  test('every guarded en key exists in hi and ml', () {
    final hi = Map.fromEntries(flatten(hindiTranslations));
    final ml = Map.fromEntries(flatten(malayalamTranslations));
    final missing = flatten(englishTranslations)
        .where((e) => guarded(e.key))
        .where((e) => !hi.containsKey(e.key) || !ml.containsKey(e.key))
        .map((e) => e.key)
        .toList();
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
