-- Bible Book Config Table
--
-- Single-row configuration table storing all canonical Bible book names
-- and their alternates/abbreviations for all supported languages.
--
-- This is the single source of truth for the frontend.
-- The backend bible-book-normalizer.ts keeps its own hardcoded copy
-- (to avoid DB round-trips during LLM normalization at cold start).
--
-- To add a new alternate spelling (no code change or deploy needed):
--   UPDATE bible_book_config
--   SET data = jsonb_set(data, '{malayalamAlternates}',
--         data->'malayalamAlternates' || '["newVariant"]'::jsonb),
--       updated_at = NOW()
--   WHERE id = 1;
--
-- Frontend clients pick up the change within 30 days (cache TTL).

CREATE TABLE IF NOT EXISTS bible_book_config (
  id          INTEGER PRIMARY KEY CHECK (id = 1),  -- enforces single row
  version     INTEGER NOT NULL DEFAULT 1,
  data        JSONB    NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- No RLS needed: this is a public, read-only reference table.
-- The Edge Function reads it via service role; no user-level access required.

-- Seed with a raw JSONB literal to avoid jsonb_build_array()'s 100-argument limit.
-- Data sourced from backend/supabase/functions/_shared/utils/bible-book-normalizer.ts
INSERT INTO bible_book_config (id, version, data, updated_at)
VALUES (
  1,
  1,
  $json${
    "english": [
      "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
      "Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings",
      "1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job",
      "Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah",
      "Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos",
      "Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai",
      "Zechariah","Malachi",
      "Matthew","Mark","Luke","John","Acts","Romans",
      "1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians",
      "Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy",
      "Titus","Philemon","Hebrews","James","1 Peter","2 Peter",
      "1 John","2 John","3 John","Jude","Revelation"
    ],
    "hindi": [
      "उत्पत्ति","निर्गमन","लैव्यव्यवस्था","गिनती","व्यवस्थाविवरण",
      "यहोशू","न्यायियों","रूत","1 शमूएल","2 शमूएल","1 राजाओं","2 राजाओं",
      "1 इतिहास","2 इतिहास","एज्रा","नहेम्याह","एस्तेर","अय्यूब",
      "भजन संहिता","नीतिवचन","सभोपदेशक","श्रेष्ठगीत","यशायाह",
      "यिर्मयाह","विलापगीत","यहेजकेल","दानिय्येल","होशे","योएल","आमोस",
      "ओबद्याह","योना","मीका","नहूम","हबक्कूक","सपन्याह","हाग्गै",
      "जकर्याह","मलाकी",
      "मत्ती","मरकुस","लूका","यूहन्ना","प्रेरितों के काम","रोमियों",
      "1 कुरिन्थियों","2 कुरिन्थियों","गलातियों","इफिसियों","फिलिप्पियों",
      "कुलुस्सियों","1 थिस्सलुनीकियों","2 थिस्सलुनीकियों","1 तीमुथियुस","2 तीमुथियुस",
      "तीतुस","फिलेमोन","इब्रानियों","याकूब","1 पतरस","2 पतरस",
      "1 यूहन्ना","2 यूहन्ना","3 यूहन्ना","यहूदा","प्रकाशितवाक्य"
    ],
    "malayalam": [
      "ഉല്പ.","പുറ.","ലേവ്യ.","സംഖ്യ.","ആവർ.",
      "യോശുവ","ന്യായാ.","രൂത്ത്","1 ശമു.","2 ശമു.",
      "1 രാജാ.","2 രാജാ.","1 ദിന.","2 ദിന.",
      "എസ്രാ","നെഹെ.","എസ്ഥേ.","ഇയ്യോ.","സങ്കീ.","സദൃ.",
      "സഭാ.","ഉത്ത.","യെശ.","യിരെ.","വിലാ.",
      "യെഹെ.","ദാനീ.","ഹോശേ.","യോവേ.","ആമോ.","ഓബ.",
      "യോനാ","മീഖാ","നഹൂം","ഹബ.","സെഫ.","ഹഗ്ഗാ.",
      "സെഖ.","മലാ.",
      "മത്താ.","മർക്കൊ.","ലൂക്കൊ.","യോഹ.","പ്രവൃത്തികൾ","റോമ.",
      "1 കൊരി.","2 കൊരി.","ഗലാ.","എഫെ.","ഫിലി.",
      "കൊലൊ.","1 തെസ്സ.","2 തെസ്സ.","1 തിമൊ.","2 തിമൊ.",
      "തീത്തൊ.","ഫിലേ.","എബ്രാ.","യാക്കോ.","1 പത്രൊ.","2 പത്രൊ.",
      "1 യോഹ.","2 യോഹ.","3 യോഹ.","യൂദാ","വെളി."
    ],
    "englishAbbreviations": [
      "Gen","Ge","Gn","Ex","Exod","Exo","Lev","Le","Lv",
      "Num","Nu","Nm","Deut","Dt","De","Josh","Jos",
      "Judg","Jdg","Jg","Ru","Rth",
      "1 Sam","1Sam","1Sa","1 S","2 Sam","2Sam","2Sa","2 S",
      "1 Kgs","1Kgs","1Ki","1 K","2 Kgs","2Kgs","2Ki","2 K",
      "1 Chr","1Chr","1Ch","2 Chr","2Chr","2Ch",
      "Neh","Ne","Est","Esth",
      "Ps","Psa","Psalm","Psalms","Pss","Prov","Pr","Pro",
      "Eccl","Ec","Ecc","Song","SoS","SS",
      "Isa","Is","Jer","Je","Jr","Lam","La",
      "Ezek","Eze","Ezk","Dan","Da","Dn",
      "Hos","Ho","Joe","Jl","Am","Obad","Ob",
      "Jon","Jnh","Mic","Mc","Nah","Na",
      "Hab","Hb","Zeph","Zep","Zp","Hag","Hg",
      "Zech","Zec","Zc","Mal","Ml",
      "Matt","Mt","Mk","Mr","Lk","Luk","Jn","Joh","Ac",
      "Rom","Ro","Rm",
      "1 Cor","1Cor","1Co","2 Cor","2Cor","2Co",
      "Gal","Ga","Eph","Ep","Phil","Php","Pp",
      "Col","Co",
      "1 Thess","1Thess","1Th","2 Thess","2Thess","2Th",
      "1 Tim","1Tim","1Ti","2 Tim","2Tim","2Ti",
      "Tit","Ti","Phlm","Phm","Pm","Heb","He",
      "Jas","Jm",
      "1 Pet","1Pet","1Pe","1P","2 Pet","2Pet","2Pe","2P",
      "1 Jn","1Jn","1Jo","2 Jn","2Jn","2Jo","3 Jn","3Jn","3Jo",
      "Jud","Rev","Re","Rv",
      "Song of Songs","Revelations","Proverb",
      "First Corinthians","Second Corinthians",
      "First Thessalonians","Second Thessalonians",
      "First Timothy","Second Timothy",
      "First Peter","Second Peter",
      "First John","Second John","Third John",
      "1st Corinthians","2nd Corinthians",
      "1st Thessalonians","2nd Thessalonians",
      "1st Timothy","2nd Timothy",
      "1st Peter","2nd Peter",
      "1st John","2nd John","3rd John",
      "The Gospel of John","The Gospel of Matthew",
      "The Gospel of Mark","The Gospel of Luke"
    ],
    "hindiAlternates": [
      "भज","भजन","प्रेरितों",
      "पहला शमूएल","दूसरा शमूएल",
      "पहला राजाओं","दूसरा राजाओं",
      "पहला इतिहास","दूसरा इतिहास",
      "पहला कुरिन्थियों","दूसरा कुरिन्थियों",
      "पहला थिस्सलुनीकियों","दूसरा थिस्सलुनीकियों",
      "पहला तीमुथियुस","दूसरा तीमुथियुस",
      "पहला पतरस","दूसरा पतरस",
      "पहला यूहन्ना","दूसरा यूहन्ना","तीसरा यूहन्ना",
      "मर्कुस","नहेमायाह",
      "1 राजा","2 राजा",
      "रोमियो","भजन-संहिता"
    ],
    "malayalamAlternates": [
      "ഉല്പത്തി","പുറപ്പാട്","ലേവ്യപുസ്തകം","സംഖ്യാപുസ്തകം",
      "ആവർത്തനം","ആവർത്തനപുസ്തകം","ന്യായാധിപന്മാർ",
      "1 ശമൂവേൽ","2 ശമൂവേൽ",
      "1 രാജാക്കന്മാർ","2 രാജാക്കന്മാർ",
      "1 ദിനവൃത്താന്തം","2 ദിനവൃത്താന്തം",
      "നെഹെമ്യാവ്","എസ്ഥേർ","ഇയ്യോബ്",
      "സങ്കീർത്തനങ്ങൾ","സദൃശവാക്യങ്ങൾ","സഭാപ്രസംഗി","ഉത്തമഗീതം",
      "യശായാ","യെശയ്യാവ്","യിരെമ്യാവ്","വിലാപങ്ങൾ","യെഹെസ്കേൽ","ദാനിയേൽ",
      "ഹോശേയ","യോവേൽ","ആമോസ്","ഓബദ്യാവ്",
      "ഹബക്കൂക്ക്","സെഫന്യാവ്","ഹഗ്ഗായി","സെഖര്യാവ്","മലാഖി",
      "മത്തായി","മർക്കൊസ്","ലൂക്കൊസ്","യോഹന്നാൻ",
      "അപ്പൊസ്തലപ്രവൃത്തികൾ","അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ",
      "റോമാക്കാർ","റോമർ","റോമര്‍",
      "1 കൊരിന്ത്യർ","2 കൊരിന്ത്യർ",
      "ഗലാത്യർ","എഫെസ്യർ","ഫിലിപ്പിയർ","കൊലൊസ്സ്യർ",
      "തെസ്സലൊനീക്യർ","1 തെസ്സലൊനീക്യർ","2 തെസ്സലൊനീക്യർ",
      "1 തിമൊഥെയൊസ്","2 തിമൊഥെയൊസ്",
      "തീത്തൊസ്","ഫിലേമോൻ","എബ്രായർ","യാക്കോബ്",
      "1 പത്രൊസ്","2 പത്രൊസ്",
      "1 യോഹന്നാൻ","2 യോഹന്നാൻ","3 യോഹന്നാൻ",
      "വെളിപ്പാട്",
      "ഒന്നാം ശമൂവേൽ","രണ്ടാം ശമൂവേൽ",
      "ഒന്നാം രാജാക്കന്മാർ","രണ്ടാം രാജാക്കന്മാർ",
      "ഒന്നാം കൊരിന്ത്യർ","രണ്ടാം കൊരിന്ത്യർ",
      "ഒന്നാം തെസ്സലൊനീക്യർ","രണ്ടാം തെസ്സലൊനീക്യർ",
      "ഒന്നാം തിമൊഥെയൊസ്","രണ്ടാം തിമൊഥെയൊസ്",
      "ഒന്നാം പത്രൊസ്","രണ്ടാം പത്രൊസ്",
      "ഒന്നാം യോഹന്നാൻ","രണ്ടാം യോഹന്നാൻ","മൂന്നാം യോഹന്നാൻ",
      "ലൂക്കാ","ലൂക്കോസ്","മർക്കോസ്","ജോൺ",
      "എഫേസ്യർ",
      "സങ്കീർത്തനം","സങ്കീര്‍ത്തനം",
      "1 പത്രോസ്","2 പത്രോസ്"
    ]
  }$json$::jsonb,
  NOW()
) ON CONFLICT (id) DO NOTHING;
