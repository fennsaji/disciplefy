-- Short display titles for learning paths.
--
-- Long path names ("1 Thessalonians: Living Ready for Christ's Return") get
-- cut off in headers and list rows. short_title is an optional, at most 28
-- character name for those places; detail screens keep the full title. Null
-- means "use the title". The learning-paths edge function returns it as
-- short_title on every path object, localized like the title.
--
-- Seeds only the paths whose title is long, plus the six guest paths, and
-- never overwrites a value already set (admin edits win on re-run).
--
-- REVIEW NEEDED: the Hindi and Malayalam short titles below are proposals and
-- need a native-speaker review before launch. They shorten the existing
-- translated titles and keep their Bible book names.
--
-- Production-safe: idempotent; both tables are small catalogue tables; the
-- CHECK constraints are added NOT VALID then validated (no long exclusive
-- lock), and lock_timeout stops the migration rather than queueing traffic.

SET LOCAL lock_timeout = '5s';

ALTER TABLE public.learning_paths ADD COLUMN IF NOT EXISTS short_title TEXT;
ALTER TABLE public.learning_path_translations ADD COLUMN IF NOT EXISTS short_title TEXT;

COMMENT ON COLUMN public.learning_paths.short_title IS
  'Optional display name (<= 28 chars) for headers and list rows; null means use title.';
COMMENT ON COLUMN public.learning_path_translations.short_title IS
  'Optional localized display name (<= 28 chars); null means use the localized title.';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'learning_paths_short_title_len'
      AND conrelid = 'public.learning_paths'::regclass
  ) THEN
    ALTER TABLE public.learning_paths
      ADD CONSTRAINT learning_paths_short_title_len
      CHECK (short_title IS NULL OR char_length(short_title) <= 28) NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'learning_path_translations_short_title_len'
      AND conrelid = 'public.learning_path_translations'::regclass
  ) THEN
    ALTER TABLE public.learning_path_translations
      ADD CONSTRAINT learning_path_translations_short_title_len
      CHECK (short_title IS NULL OR char_length(short_title) <= 28) NOT VALID;
  END IF;
END $$;

ALTER TABLE public.learning_paths VALIDATE CONSTRAINT learning_paths_short_title_len;
ALTER TABLE public.learning_path_translations VALIDATE CONSTRAINT learning_path_translations_short_title_len;

-- English (learning_paths.short_title)
UPDATE public.learning_paths lp SET short_title = v.short_title
FROM (VALUES
  ('1-thessalonians-living-ready', '1 Thessalonians'),
  ('2-thessalonians-standing-firm', '2 Thessalonians'),
  ('crucifixion-and-resurrection', 'Cross and Resurrection'),
  ('johns-letters-light-love-truth', 'John''s Letters'),
  ('responding-to-cults', 'Responding to Cults'),
  ('mental-health-emotions-gospel', 'Emotions and the Gospel'),
  ('colossians-supremacy-of-christ', 'Colossians: Christ Supreme'),
  ('historical-reliability-bible', 'Is the Bible Reliable?'),
  ('titus-sound-doctrine-sound-living', 'Titus: Sound Doctrine'),
  ('peters-letters-hope-and-endurance', 'Peter''s Letters'),
  ('sin-repentance-and-grace', 'Sin, Repentance & Grace'),
  ('corinthians-christ-and-his-church', 'Corinthians: Christ''s Church'),
  ('philemon-forgiveness-and-reconciliation', 'Philemon: A Brother'),
  ('friendship-and-christian-community', 'Friendship & Community'),
  ('1-timothy-household-of-god', '1 Timothy: God''s Household'),
  ('revelation-the-lamb-who-reigns', 'Revelation: The Lamb Reigns'),
  ('money-generosity-gospel', 'Money & Generosity'),
  ('hebrews-jesus-our-high-priest', 'Hebrews: Our High Priest'),
  ('singleness-dating-marriage', 'Singleness, Dating, Marriage'),
  ('new-believer-essentials', 'New Believer Essentials'),
  ('growing-in-discipleship', 'Growing in Discipleship'),
  ('theology-of-suffering', 'Theology of Suffering'),
  ('gospel-of-mark', 'Gospel of Mark'),
  ('romans-gospel-unfolded', 'Romans: Gospel Unfolded')
) AS v(slug, short_title)
WHERE lp.slug = v.slug AND lp.short_title IS NULL;

-- Hindi and Malayalam (learning_path_translations.short_title).
-- Proposals: native-speaker review required before launch.
UPDATE public.learning_path_translations t SET short_title = v.short_title
FROM (VALUES
  -- Guest paths
  ('new-believer-essentials', 'hi', 'नए विश्वासी की मूल बातें'),
  ('new-believer-essentials', 'ml', 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ'),
  ('sin-repentance-and-grace', 'hi', 'पाप, पश्चाताप और अनुग्रह'),
  ('sin-repentance-and-grace', 'ml', 'പാപം, അനുതാപം, കൃപ'),
  ('growing-in-discipleship', 'hi', 'शिष्यता में बढ़ना'),
  ('growing-in-discipleship', 'ml', 'ശിഷ്യത്വത്തിൽ വളരുക'),
  ('theology-of-suffering', 'hi', 'दुख को समझना'),
  ('theology-of-suffering', 'ml', 'കഷ്ടത്തിൽ ദൈവത്തെ കണ്ടെത്തൽ'),
  ('gospel-of-mark', 'hi', 'मरकुस का सुसमाचार'),
  ('gospel-of-mark', 'ml', 'മര്‍ക്കൊസിന്റെ സുവിശേഷം'),
  ('romans-gospel-unfolded', 'hi', 'रोमियों: सुसमाचार का प्रकाशन'),
  ('romans-gospel-unfolded', 'ml', 'റോമർ: സുവിശേഷത്തിന്റെ ആഴം'),
  -- Long titles
  ('1-thessalonians-living-ready', 'hi', '1 थिस्सलुनीकियों'),
  ('1-thessalonians-living-ready', 'ml', '1 തെസ്സലൊനീക്യർ'),
  ('2-thessalonians-standing-firm', 'hi', '2 थिस्सलुनीकियों'),
  ('2-thessalonians-standing-firm', 'ml', '2 തെസ്സലൊനീക്യർ'),
  ('1-timothy-household-of-god', 'hi', '1 तीमुथियुस: परमेश्वर का घर'),
  ('1-timothy-household-of-god', 'ml', '1 തിമൊഥെയൊസ്: ദൈവഭവനം'),
  ('2-timothy-guard-the-good-deposit', 'hi', '2 तीमुथियुस: दौड़ पूरी करो'),
  ('2-timothy-guard-the-good-deposit', 'ml', '2 തിമൊഥെയൊസ്'),
  ('baptism-and-lords-supper', 'ml', 'സ്നാനവും തിരുവത്താഴവും'),
  ('colossians-supremacy-of-christ', 'hi', 'कुलुस्सियों: सर्वोच्च मसीह'),
  ('colossians-supremacy-of-christ', 'ml', 'കൊലൊസ്സ്യർ'),
  ('corinthians-christ-and-his-church', 'hi', 'कुरिन्थियों: मसीह की कलीसिया'),
  ('corinthians-christ-and-his-church', 'ml', 'കൊരിന്ത്യർ: ക്രിസ്തുസഭ'),
  ('crucifixion-and-resurrection', 'hi', 'क्रूस और पुनरुत्थान'),
  ('crucifixion-and-resurrection', 'ml', 'ക്രൂശും പുനരുത്ഥാനവും'),
  ('deepening-your-walk', 'ml', 'നടത്തം ആഴത്തിലാക്കുക'),
  ('defending-your-faith', 'ml', 'വിശ്വാസം സംരക്ഷിക്കുക'),
  ('ephesians-riches-in-christ', 'ml', 'എഫെസ്യർ: ക്രിസ്തുവിലെ ധനം'),
  ('evangelism-everyday-life', 'hi', 'हर दिन सुसमाचार'),
  ('evangelism-everyday-life', 'ml', 'ദിവസവും സുവിശേഷം'),
  ('galatians-gospel-freedom', 'hi', 'गलातियों: सुसमाचार की आज़ादी'),
  ('galatians-gospel-freedom', 'ml', 'ഗലാത്യർ: സ്വാതന്ത്ര്യം'),
  ('hebrews-jesus-our-high-priest', 'hi', 'इब्रानियों: महायाजक यीशु'),
  ('historical-reliability-bible', 'hi', 'बाइबल की विश्वसनीयता'),
  ('historical-reliability-bible', 'ml', 'ബൈബിളിന്റെ വിശ്വാസ്യത'),
  ('james-faith-that-works', 'hi', 'याकूब: सक्रिय विश्वास'),
  ('james-faith-that-works', 'ml', 'യാക്കോബ്: ജീവനുള്ള വിശ്വാസം'),
  ('johns-letters-light-love-truth', 'hi', 'यूहन्ना के पत्र'),
  ('johns-letters-light-love-truth', 'ml', 'യോഹന്നാന്റെ ലേഖനങ്ങൾ'),
  ('jude-contend-for-the-faith', 'hi', 'यहूदा: विश्वास के लिए लड़ो'),
  ('jude-contend-for-the-faith', 'ml', 'യൂദാ: വിശ്വാസപ്പോരാട്ടം'),
  ('mental-health-emotions-gospel', 'hi', 'मन और सुसमाचार'),
  ('mental-health-emotions-gospel', 'ml', 'മനസ്സും സുവിശേഷവും'),
  ('peters-letters-hope-and-endurance', 'hi', 'पतरस के पत्र'),
  ('peters-letters-hope-and-endurance', 'ml', 'പത്രോസിന്റെ ലേഖനങ്ങൾ'),
  ('philippians-joy-in-christ', 'ml', 'ഫിലിപ്പിയർ: ആനന്ദം'),
  ('responding-to-cults', 'hi', 'झूठी शिक्षाओं का जवाब'),
  ('responding-to-cults', 'ml', 'ദുരുപദേശങ്ങൾക്ക് മറുപടി'),
  ('revelation-the-lamb-who-reigns', 'hi', 'प्रकाशितवाक्य: राजा मेम्ना'),
  ('singleness-dating-marriage', 'hi', 'अविवाहित, डेटिंग और विवाह'),
  ('singleness-dating-marriage', 'ml', 'ഏകജീവിതം, ഡേറ്റിംഗ്, വിവാഹം'),
  ('titus-sound-doctrine-sound-living', 'hi', 'तीतुस: खरा सिद्धांत'),
  ('titus-sound-doctrine-sound-living', 'ml', 'തീത്തൊസ്: സത്യോപദേശം'),
  ('work-and-vocation-as-worship', 'hi', 'काम भी आराधना')
) AS v(slug, lang, short_title)
JOIN public.learning_paths lp ON lp.slug = v.slug
WHERE t.learning_path_id = lp.id AND t.lang_code = v.lang AND t.short_title IS NULL;

-- English translation rows (a few paths have one) mirror the base short title.
UPDATE public.learning_path_translations t SET short_title = lp.short_title
FROM public.learning_paths lp
WHERE t.learning_path_id = lp.id
  AND t.lang_code = 'en'
  AND t.short_title IS NULL
  AND lp.short_title IS NOT NULL;
