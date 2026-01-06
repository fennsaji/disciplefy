-- ============================================================================
-- Migration: Create Theology & Philosophy Topics
-- Date: 2026-01-07
-- Description: Creates 9 new theological and philosophical question topics
--              for the "Faith & Reason" learning path
-- ============================================================================

BEGIN;

-- ============================================================================
-- Category: Theology & Philosophy
-- ============================================================================

-- Create 9 new topics addressing popular theological/philosophical questions
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value)
VALUES
  -- 1. Does God Exist?
  ('AAA00000-e29b-41d4-a716-446655440001',
   'Does God Exist?',
   'Examining philosophical and biblical evidence for God''s existence through cosmological, teleological, and moral arguments.',
   'Theology & Philosophy',
   ARRAY['existence of god', 'apologetics', 'philosophy', 'cosmology', 'evidence'],
   56, 50),

  -- 2. Why Does God Allow Evil and Suffering?
  ('AAA00000-e29b-41d4-a716-446655440002',
   'Why Does God Allow Evil and Suffering?',
   'Understanding theodicy, free will, and God''s sovereignty in a fallen world. Biblical perspectives on pain and redemption.',
   'Theology & Philosophy',
   ARRAY['problem of evil', 'theodicy', 'suffering', 'free will', 'sovereignty'],
   57, 50),

  -- 3. Is Jesus the Only Way to Salvation?
  ('AAA00000-e29b-41d4-a716-446655440003',
   'Is Jesus the Only Way to Salvation?',
   'Exploring biblical exclusivity claims, Jesus'' own words, and responding to pluralism with grace and truth.',
   'Theology & Philosophy',
   ARRAY['salvation', 'exclusivity', 'jesus', 'pluralism', 'soteriology'],
   58, 50),

  -- 4. What About Those Who Never Hear the Gospel?
  ('AAA00000-e29b-41d4-a716-446655440004',
   'What About Those Who Never Hear the Gospel?',
   'Biblical perspectives on general revelation, God''s justice, and the fate of the unreached.',
   'Theology & Philosophy',
   ARRAY['unreached', 'general revelation', 'justice', 'missions', 'romans 1-2'],
   59, 50),

  -- 5. What is the Trinity?
  ('AAA00000-e29b-41d4-a716-446655440005',
   'What is the Trinity?',
   'Understanding the nature of God as one being in three persons - Father, Son, and Holy Spirit.',
   'Theology & Philosophy',
   ARRAY['trinity', 'god', 'theology', 'monotheism', 'godhead'],
   60, 50),

  -- 6. Why Doesn''t God Answer My Prayers?
  ('AAA00000-e29b-41d4-a716-446655440006',
   'Why Doesn''t God Answer My Prayers?',
   'Understanding God''s timing, His will, and the purpose of persistent prayer in light of unanswered petitions.',
   'Theology & Philosophy',
   ARRAY['prayer', 'unanswered prayer', 'gods will', 'faith', 'persistence'],
   61, 50),

  -- 7. Predestination vs. Free Will
  ('AAA00000-e29b-41d4-a716-446655440007',
   'Predestination vs. Free Will',
   'Exploring God''s sovereignty and human responsibility - biblical tensions, Reformed vs. Arminian perspectives.',
   'Theology & Philosophy',
   ARRAY['predestination', 'free will', 'sovereignty', 'election', 'calvinism'],
   62, 50),

  -- 8. Why Are There So Many Christian Denominations?
  ('AAA00000-e29b-41d4-a716-446655440008',
   'Why Are There So Many Christian Denominations?',
   'Understanding church history, essential vs. non-essential doctrines, and unity in diversity.',
   'Theology & Philosophy',
   ARRAY['denominations', 'church history', 'unity', 'doctrine', 'ecclesiology'],
   63, 50),

  -- 9. What is My Purpose in Life?
  ('AAA00000-e29b-41d4-a716-446655440009',
   'What is My Purpose in Life?',
   'Discovering God''s design for your life through creation, redemption, and your unique calling.',
   'Theology & Philosophy',
   ARRAY['purpose', 'calling', 'identity', 'meaning', 'vocation'],
   64, 50)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- TRANSLATIONS: Hindi (hi)
-- ============================================================================

INSERT INTO recommended_topics_translations (topic_id, lang_code, category, title, description)
VALUES
  -- 1. Does God Exist?
  ('AAA00000-e29b-41d4-a716-446655440001', 'hi',
   'धर्मशास्त्र और दर्शन',
   'क्या परमेश्वर है?',
   'ब्रह्मांडीय, उद्देश्यमूलक और नैतिक तर्कों के माध्यम से परमेश्वर के अस्तित्व के लिए दार्शनिक और बाइबिलीय साक्ष्य की जांच।'),

  -- 2. Why Does God Allow Evil and Suffering?
  ('AAA00000-e29b-41d4-a716-446655440002', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर बुराई और पीड़ा क्यों होने देता है?',
   'पतित संसार में थियोडिसी, स्वतंत्र इच्छा और परमेश्वर की संप्रभुता को समझना। दर्द और छुटकारे पर बाइबिलीय दृष्टिकोण।'),

  -- 3. Is Jesus the Only Way to Salvation?
  ('AAA00000-e29b-41d4-a716-446655440003', 'hi',
   'धर्मशास्त्र और दर्शन',
   'क्या यीशु ही उद्धार का एकमात्र रास्ता है?',
   'बाइबिलीय विशिष्टता के दावों, यीशु के अपने शब्दों की खोज और कृपा और सत्य के साथ बहुलवाद पर प्रतिक्रिया।'),

  -- 4. What About Those Who Never Hear the Gospel?
  ('AAA00000-e29b-41d4-a716-446655440004', 'hi',
   'धर्मशास्त्र और दर्शन',
   'उनके बारे में क्या जो कभी सुसमाचार नहीं सुनते?',
   'सामान्य प्रकाशन, परमेश्वर की न्याय और अप्राप्त लोगों के भाग्य पर बाइबिलीय दृष्टिकोण।'),

  -- 5. What is the Trinity?
  ('AAA00000-e29b-41d4-a716-446655440005', 'hi',
   'धर्मशास्त्र और दर्शन',
   'त्रिएकता क्या है?',
   'तीन व्यक्तियों - पिता, पुत्र और पवित्र आत्मा में एक परमेश्वर के रूप में परमेश्वर की प्रकृति को समझना।'),

  -- 6. Why Doesn't God Answer My Prayers?
  ('AAA00000-e29b-41d4-a716-446655440006', 'hi',
   'धर्मशास्त्र और दर्शन',
   'परमेश्वर मेरी प्रार्थनाओं का उत्तर क्यों नहीं देता?',
   'अनुत्तरित याचनाओं के प्रकाश में परमेश्वर के समय, उसकी इच्छा और लगातार प्रार्थना के उद्देश्य को समझना।'),

  -- 7. Predestination vs. Free Will
  ('AAA00000-e29b-41d4-a716-446655440007', 'hi',
   'धर्मशास्त्र और दर्शन',
   'पूर्वनियति बनाम स्वतंत्र इच्छा',
   'परमेश्वर की संप्रभुता और मानव जिम्मेदारी की खोज - बाइबिलीय तनाव, सुधारवादी बनाम आर्मिनियन दृष्टिकोण।'),

  -- 8. Why Are There So Many Christian Denominations?
  ('AAA00000-e29b-41d4-a716-446655440008', 'hi',
   'धर्मशास्त्र और दर्शन',
   'इतने सारे ईसाई संप्रदाय क्यों हैं?',
   'कलीसिया के इतिहास, आवश्यक बनाम गैर-आवश्यक सिद्धांतों और विविधता में एकता को समझना।'),

  -- 9. What is My Purpose in Life?
  ('AAA00000-e29b-41d4-a716-446655440009', 'hi',
   'धर्मशास्त्र और दर्शन',
   'मेरे जीवन का उद्देश्य क्या है?',
   'सृष्टि, छुटकारे और अपने अनोखे बुलावे के माध्यम से अपने जीवन के लिए परमेश्वर की योजना को खोजना।')
ON CONFLICT (topic_id, lang_code) DO NOTHING;

-- ============================================================================
-- TRANSLATIONS: Malayalam (ml)
-- ============================================================================

INSERT INTO recommended_topics_translations (topic_id, lang_code, category, title, description)
VALUES
  -- 1. Does God Exist?
  ('AAA00000-e29b-41d4-a716-446655440001', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം നിലനിൽക്കുന്നുണ്ടോ?',
   'പ്രപഞ്ചശാസ്ത്രപരവും ലക്ഷ്യപരവും നൈതികവുമായ വാദങ്ങളിലൂടെ ദൈവത്തിന്റെ നിലനിൽപ്പിന് തത്ത്വചിന്തയും ബൈബിളും തെളിവുകൾ പരിശോധിക്കുന്നു.'),

  -- 2. Why Does God Allow Evil and Suffering?
  ('AAA00000-e29b-41d4-a716-446655440002', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ദൈവം തിന്മയും കഷ്ടപ്പാടും എന്തുകൊണ്ട് അനുവദിക്കുന്നു?',
   'പതിച്ച ലോകത്തിൽ ദൈവശാസ്ത്രം, സ്വതന്ത്രഹിതം, ദൈവത്തിന്റെ പരമാധികാരം എന്നിവ മനസ്സിലാക്കുന്നു. വേദനയും വീണ്ടെടുപ്പും സംബന്ധിച്ച ബൈബിൾ വീക്ഷണങ്ങൾ.'),

  -- 3. Is Jesus the Only Way to Salvation?
  ('AAA00000-e29b-41d4-a716-446655440003', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'യേശു രക്ഷയുടെ ഏക മാർഗമാണോ?',
   'ബൈബിൾ പ്രത്യേകാവകാശ അവകാശവാദങ്ങൾ, യേശുവിന്റെ സ്വന്തം വാക്കുകൾ പര്യവേക്ഷണം ചെയ്യുകയും കൃപയോടും സത്യത്തോടും കൂടി ബഹുത്വവാദത്തോട് പ്രതികരിക്കുകയും ചെയ്യുന്നു.'),

  -- 4. What About Those Who Never Hear the Gospel?
  ('AAA00000-e29b-41d4-a716-446655440004', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ഒരിക്കലും സുവിശേഷം കേൾക്കാത്തവരെക്കുറിച്ചോ?',
   'സാമാന്യ വെളിപാട്, ദൈവത്തിന്റെ നീതി, എത്തിപ്പെടാത്തവരുടെ വിധി എന്നിവയെക്കുറിച്ചുള്ള ബൈബിൾ കാഴ്ചപ്പാടുകൾ.'),

  -- 5. What is the Trinity?
  ('AAA00000-e29b-41d4-a716-446655440005', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'ത്രിത്വം എന്താണ്?',
   'മൂന്ന് വ്യക്തികളിൽ - പിതാവ്, പുത്രൻ, പരിശുദ്ധാത്മാവ് - ഒരു ദൈവമെന്ന നിലയിൽ ദൈവത്തിന്റെ സ്വഭാവം മനസ്സിലാക്കുന്നു.'),

  -- 6. Why Doesn't God Answer My Prayers?
  ('AAA00000-e29b-41d4-a716-446655440006', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ദൈവം എന്റെ പ്രാർത്ഥനകൾക്ക് ഉത്തരം നൽകുന്നില്ല?',
   'ഉത്തരം ലഭിക്കാത്ത അപേക്ഷകളുടെ വെളിച്ചത്തിൽ ദൈവത്തിന്റെ സമയം, അവന്റെ ഇഷ്ടം, സ്ഥിരതയുള്ള പ്രാർത്ഥനയുടെ ഉദ്ദേശ്യം എന്നിവ മനസ്സിലാക്കുന്നു.'),

  -- 7. Predestination vs. Free Will
  ('AAA00000-e29b-41d4-a716-446655440007', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'മുൻനിശ്ചയം വേഴ്സസ് സ്വതന്ത്ര ഹിതം',
   'ദൈവത്തിന്റെ പരമാധികാരവും മാനുഷിക ഉത്തരവാദിത്തവും പര്യവേക്ഷണം ചെയ്യുന്നു - ബൈബിൾ പിരിമുറുക്കങ്ങൾ, പരിഷ്കരിച്ച വേഴ്സസ് ആർമിനിയൻ കാഴ്ചപ്പാടുകൾ.'),

  -- 8. Why Are There So Many Christian Denominations?
  ('AAA00000-e29b-41d4-a716-446655440008', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്തുകൊണ്ട് ഇത്ര ധാരാളം ക്രൈസ്തവ വിഭാഗങ്ങളുണ്ട്?',
   'സഭാ ചരിത്രം, അവശ്യവും അനാവശ്യകവുമായ ഉപദേശങ്ങൾ, വൈവിധ്യത്തിലെ ഐക്യം എന്നിവ മനസ്സിലാക്കുന്നു.'),

  -- 9. What is My Purpose in Life?
  ('AAA00000-e29b-41d4-a716-446655440009', 'ml',
   'ദൈവശാസ്ത്രവും തത്ത്വചിന്തയും',
   'എന്റെ ജീവിതത്തിന്റെ ഉദ്ദേശ്യം എന്താണ്?',
   'സൃഷ്ടി, വീണ്ടെടുപ്പ്, നിങ്ങളുടെ അതുല്യമായ വിളി എന്നിവയിലൂടെ നിങ്ങളുടെ ജീവിതത്തിനായുള്ള ദൈവത്തിന്റെ രൂപകല്പന കണ്ടെത്തുന്നു.')
ON CONFLICT (topic_id, lang_code) DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
  topic_count INTEGER;
  hi_translation_count INTEGER;
  ml_translation_count INTEGER;
BEGIN
  -- Count newly created topics
  SELECT COUNT(*) INTO topic_count
  FROM recommended_topics
  WHERE id IN (
    'AAA00000-e29b-41d4-a716-446655440001',
    'AAA00000-e29b-41d4-a716-446655440002',
    'AAA00000-e29b-41d4-a716-446655440003',
    'AAA00000-e29b-41d4-a716-446655440004',
    'AAA00000-e29b-41d4-a716-446655440005',
    'AAA00000-e29b-41d4-a716-446655440006',
    'AAA00000-e29b-41d4-a716-446655440007',
    'AAA00000-e29b-41d4-a716-446655440008',
    'AAA00000-e29b-41d4-a716-446655440009'
  );

  -- Count Hindi translations
  SELECT COUNT(*) INTO hi_translation_count
  FROM recommended_topics_translations
  WHERE lang_code = 'hi'
    AND topic_id::text LIKE 'aaa00000%';

  -- Count Malayalam translations
  SELECT COUNT(*) INTO ml_translation_count
  FROM recommended_topics_translations
  WHERE lang_code = 'ml'
    AND topic_id::text LIKE 'aaa00000%';

  IF topic_count != 9 THEN
    RAISE EXCEPTION 'Expected 9 topics, found %', topic_count;
  END IF;

  IF hi_translation_count != 9 THEN
    RAISE EXCEPTION 'Expected 9 Hindi translations, found %', hi_translation_count;
  END IF;

  IF ml_translation_count != 9 THEN
    RAISE EXCEPTION 'Expected 9 Malayalam translations, found %', ml_translation_count;
  END IF;

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Created % theology & philosophy topics', topic_count;
  RAISE NOTICE '  - Created % Hindi translations', hi_translation_count;
  RAISE NOTICE '  - Created % Malayalam translations', ml_translation_count;
END $$;

COMMIT;
