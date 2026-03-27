-- =====================================================
-- Migration: Fix Crucifixion Topics UUID Collision
-- =====================================================
-- Root cause: ab400000...001-005 were first created as Work & Vocation topics
-- in 20260223000001_new_learning_paths.sql. The Crucifixion v2 migration
-- (20260313000001) used ON CONFLICT DO NOTHING so base English content for
-- those 5 IDs was never updated. Hindi/ML translations were added correctly
-- in 20260316000003_learning_path_topic_translations.sql, causing a mismatch
-- where English shows Work content and Hindi/ML shows Crucifixion content.
-- (Same pattern as Romans/Evangelism collision fixed in 20260327000001.)
--
-- Fix:
--   1. UPDATE base recommended_topics (English) to Crucifixion content for 001-005
--   2. Create new IDs (ab190000) for the 5 Work & Vocation topics
--   3. Insert Hindi & Malayalam translations for the new Work topic IDs
--   4. Re-link Work & Vocation learning path (019) to new topic IDs
-- =====================================================

BEGIN;

-- =====================================================
-- PART 1: Fix base English topics (recommended_topics)
--         Update IDs 001-005 to correct Crucifixion content
-- =====================================================

UPDATE recommended_topics SET
  title = 'The Last Supper',
  description = 'On the night of his betrayal, Jesus gathered his disciples, broke bread, and shared wine — inaugurating the new covenant in his body and blood. This final meal carries Passover memory, covenant language, and the institution of the Lord''s Supper as a lasting memorial of his atoning death. It is also a meal of remarkable intimacy — Jesus washing feet, promising the Spirit, praying for his own. The elements of bread and wine do not become Christ''s body and blood but are signs and seals of the covenant grace received through faith in his once-for-all atoning sacrifice.',
  category = 'Foundations of Faith',
  tags = ARRAY['crucifixion', 'last supper', 'covenant', 'atonement'],
  display_order = 365
WHERE id = 'ab400000-e29b-41d4-a716-446655440001';

UPDATE recommended_topics SET
  title = 'The Garden of Gethsemane',
  description = 'In Gethsemane, Jesus falls on his face and prays: "Father, if it is possible, let this cup pass from me; yet not as I will, but as you will." This is not the prayer of a reluctant victim but of the eternal Son in genuine agony, bearing the weight of what lies ahead. Jesus watches while the disciples sleep — showing both his solidarity with human weakness and his unique, unshared burden. (Matt 26:36-46)',
  category = 'Foundations of Faith',
  tags = ARRAY['crucifixion', 'gethsemane', 'prayer', 'suffering'],
  display_order = 366
WHERE id = 'ab400000-e29b-41d4-a716-446655440002';

UPDATE recommended_topics SET
  title = 'Betrayal and Arrest',
  description = 'Judas arrives with a crowd of chief priests and elders, identifies Jesus with a kiss, and Jesus is seized. One disciple draws a sword; Jesus rebukes him and heals the servant''s ear. Then all the disciples flee. This moment fulfills Scripture and marks the complete transfer of Jesus into the hands of those who will kill him — yet he goes willingly. (Matt 26:47-56)',
  category = 'Foundations of Faith',
  tags = ARRAY['crucifixion', 'betrayal', 'arrest', 'fulfillment'],
  display_order = 367
WHERE id = 'ab400000-e29b-41d4-a716-446655440003';

UPDATE recommended_topics SET
  title = 'Peter''s Denial',
  description = 'Three times Peter is identified as a follower of Jesus. Three times he denies it with increasing intensity — "I do not know the man." At the third denial the rooster crows, Peter remembers Jesus''s words, and goes out and weeps bitterly. His fall is a reminder that even genuine faith can crumble under pressure, and a foreshadowing of the grace that would restore him.',
  category = 'Foundations of Faith',
  tags = ARRAY['crucifixion', 'peter', 'denial', 'failure'],
  display_order = 368
WHERE id = 'ab400000-e29b-41d4-a716-446655440004';

UPDATE recommended_topics SET
  title = 'Jesus Before the Sanhedrin',
  description = 'The council seeks false testimony to put Jesus to death. When the high priest asks, "Are you the Christ, the Son of God?" Jesus answers, "You have said so. And I tell you, from now on you will see the Son of Man seated at the right hand of Power and coming on the clouds of heaven." The council declares blasphemy and condemns him to death.',
  category = 'Foundations of Faith',
  tags = ARRAY['crucifixion', 'trial', 'identity', 'messiah'],
  display_order = 369
WHERE id = 'ab400000-e29b-41d4-a716-446655440005';


-- =====================================================
-- PART 2: Create replacement topic IDs for Work & Vocation path (019)
--         Using ab190000 prefix (19 = path number)
-- =====================================================

INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES
  ('ab190000-e29b-41d4-a716-446655440001', 'Work Before and After the Fall',
   'Work was given to humanity before sin entered the world — it is a gift, not a punishment. The Fall introduced frustration, futility, and thorns into our labor, but Christ''s redemption restores meaning to work. This study traces the biblical theology of work from Genesis to the New Creation, where our redeemed labor continues in a renewed world.',
   'Christian Living', ARRAY['work', 'vocation', 'creation', 'fall'], 281, 50),

  ('ab190000-e29b-41d4-a716-446655440002', 'Your Calling: More Than a Job',
   'Every believer has a primary calling — to follow Christ — and a secondary calling expressed through a particular vocation, role, and season of life. Study what it means to discern and live out your calling, how to hold your career in an open hand, and why the question is not "What do I do?" but "Who am I serving?"',
   'Christian Living', ARRAY['calling', 'vocation', 'purpose', 'discipleship'], 282, 50),

  ('ab190000-e29b-41d4-a716-446655440003', 'Excellence and Integrity at Work',
   'Colossians 3:23 commands believers to work at everything heartily, as for the Lord. Excellence is not workaholism — it is faithful stewardship of the time and talent God has entrusted to you. This study explores what integrity looks like in professional settings: honesty, diligence, fair dealing, and resisting the temptation to cut corners.',
   'Christian Living', ARRAY['integrity', 'excellence', 'work', 'stewardship'], 283, 50),

  ('ab190000-e29b-41d4-a716-446655440004', 'Being a Witness in the Workplace',
   'The workplace is one of the primary mission fields for most believers — a context where Christians can embody the gospel through character, conversation, and care for colleagues. Study how to be a credible witness at work without being preachy, how to navigate ethical tensions, and how to build genuine relationships that open doors for the gospel.',
   'Mission & Evangelism', ARRAY['witness', 'workplace', 'mission', 'character'], 284, 50),

  ('ab190000-e29b-41d4-a716-446655440005', 'Rest, Sabbath, and Rhythm',
   'God worked and then rested — and He commands His people to do the same. The Sabbath is not merely a rule but a rhythm of trust: declaring that God sustains the world, not our productivity. Study the theology of rest, how Sabbath points to Christ as our ultimate rest, and how regular rhythms of work and rest reflect the image of a working, resting God.',
   'Spiritual Disciplines', ARRAY['rest', 'sabbath', 'rhythm', 'trust'], 285, 50)

ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- PART 3: Hindi translations for new Work & Vocation topic IDs
-- =====================================================

INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('ab190000-e29b-41d4-a716-446655440001', 'hi',
   'पतन से पहले और बाद में काम',
   'पाप आने से पहले भी काम था — यह श्राप नहीं, परमेश्वर का वरदान है। पतन ने काम में कठिनाई और निराशा लाई, लेकिन मसीह की छुड़ाहट काम को फिर से अर्थपूर्ण बनाती है। उत्पत्ति से नई सृष्टि तक बाइबल में काम की धर्मशास्त्रीय दृष्टि खोजें।',
   'मसीही जीवन'),
  ('ab190000-e29b-41d4-a716-446655440002', 'hi',
   'आपकी बुलाहट: एक नौकरी से बढ़कर',
   'हर विश्वासी की एक प्राथमिक बुलाहट है — मसीह का अनुसरण करना — और एक विशेष बुलाहट जो उनके काम में व्यक्त होती है। "मैं क्या करता हूँ?" नहीं, बल्कि "मैं किसकी सेवा कर रहा हूँ?" — यही सही सवाल है।',
   'मसीही जीवन'),
  ('ab190000-e29b-41d4-a716-446655440003', 'hi',
   'काम में उत्कृष्टता और ईमानदारी',
   'कुलुस्सियों 3:23 कहता है — जो कुछ भी करो, प्रभु के लिए मन से करो। उत्कृष्टता का अर्थ कार्यव्यसन नहीं, बल्कि परमेश्वर की दी हुई प्रतिभा का विश्वसनीय उपयोग है। व्यावसायिक जीवन में ईमानदारी, परिश्रम और उचित व्यवहार मसीही साक्ष्य का हिस्सा है।',
   'मसीही जीवन'),
  ('ab190000-e29b-41d4-a716-446655440004', 'hi',
   'कार्यक्षेत्र में गवाही देना',
   'कार्यस्थल अधिकांश विश्वासियों के लिए प्रमुख मिशन क्षेत्र है। चरित्र, बातचीत और सहकर्मियों की देखभाल के माध्यम से सुसमाचार को जीना सीखें। उपदेशबाज़ बने बिना विश्वसनीय गवाह कैसे बनें, यह इस अध्ययन में मिलेगा।',
   'मिशन और सुसमाचार'),
  ('ab190000-e29b-41d4-a716-446655440005', 'hi',
   'विश्राम, सब्त और जीवन की लय',
   'परमेश्वर ने काम किया और फिर विश्राम किया — और वह अपने लोगों को भी वैसा करने की आज्ञा देता है। सब्त केवल नियम नहीं, बल्कि विश्वास की लय है — यह घोषणा करता है कि परमेश्वर संसार को संभालता है, हमारी उत्पादकता नहीं। सब्त मसीह की ओर — हमारे असली विश्राम की ओर — इशारा करता है।',
   'आत्मिक अनुशासन')
ON CONFLICT (topic_id, language_code) DO NOTHING;


-- =====================================================
-- PART 4: Malayalam translations for new Work & Vocation topic IDs
-- =====================================================

INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES
  ('ab190000-e29b-41d4-a716-446655440001', 'ml',
   'പതനത്തിനു മുൻപും ശേഷവും ജോലി',
   'പാപം വരുന്നതിനു മുൻപും ജോലി ഉണ്ടായിരുന്നു — ഇത് ശാപമല്ല, ദൈവദാനമാണ്. പതനം ജോലിയിൽ ക്ലേശവും നിരർഥകതയും കൊണ്ടുവന്നു. ക്രിസ്തുവിന്റെ വീണ്ടെടുപ്പ് ജോലിക്ക് അർഥം പുനഃസ്ഥാപിക്കുന്നു. ഉൽപ്പത്തി മുതൽ നൂതന സൃഷ്ടി വരെ ജോലിയുടെ ദൈവശാസ്ത്ര ദൃഷ്ടി പഠിക്കുക.',
   'ക്രിസ്ത്യൻ ജീവിതം'),
  ('ab190000-e29b-41d4-a716-446655440002', 'ml',
   'നിന്റെ വിളി: ഒരു ജോലിയിൽ കൂടുതൽ',
   'ഓരോ വിശ്വാസിക്കും ഒരു പ്രധാന വിളി ഉണ്ട് — ക്രിസ്തുവിനെ അനുഗമിക്കുക — അതോടൊപ്പം ഒരു പ്രത്യേക ജീവിതവഴിയും. "ഞാൻ എന്ത് ചെയ്യുന്നു?" എന്നല്ല, "ഞാൻ ആരെ സേവിക്കുന്നു?" എന്നതാണ് ശരിയായ ചോദ്യം.',
   'ക്രിസ്ത്യൻ ജീവിതം'),
  ('ab190000-e29b-41d4-a716-446655440003', 'ml',
   'ജോലിയിൽ മികവും ആത്മനിഷ്ഠയും',
   'കൊലോ 3:23 പ്രകാരം — ഏതൊന്ന് ചെയ്താലും കർത്താവിനുവേണ്ടി ഹൃദ്യത്തോടെ ചെയ്യുക. മികവ് ജോലിവ്യഗ്രതയല്ല, ദൈവദാനങ്ങളുടെ വിശ്വസ്ത ഉപയോഗമാണ്. ആത്മനിഷ്ഠ, കഠിനാദ്ധ്വാനം, ന്യായമായ ഇടപാട് ഇവ ക്രിസ്ത്യൻ സാക്ഷ്യത്തിന്റെ ഭാഗമാണ്.',
   'ക്രിസ്ത്യൻ ജീവിതം'),
  ('ab190000-e29b-41d4-a716-446655440004', 'ml',
   'ജോലിസ്ഥലത്ത് സാക്ഷ്യം',
   'ജോലിസ്ഥലം ഭൂരിഭാഗം വിശ്വാസികൾക്കും പ്രധാന മിഷൻ ക്ഷേത്രമാണ്. സ്വഭാവം, സംഭാഷണം, സഹപ്രവർത്തകരോടുള്ള കരുതൽ വഴി സുവിശേഷം ജീവിക്കാൻ പഠിക്കുക. പ്രസംഗക്കാരനാകാതെ, വിശ്വസ്ത സാക്ഷിയായി ജീവിക്കുക.',
   'ദൗത്യവും സുവിശേഷ പ്രഘോഷണവും'),
  ('ab190000-e29b-41d4-a716-446655440005', 'ml',
   'വിശ്രാന്തി, ശബ്ബത്ത്, ജീവിതക്രമം',
   'ദൈവം ജോലി ചെയ്ത് വിശ്രമിച്ചു — തന്റെ ജനത്തോടും അതേ ചെയ്യാൻ ആജ്ഞ നൽകി. ശബ്ബത്ത് ഒരു ചട്ടം മാത്രമല്ല, വിശ്വാസത്തിന്റെ ക്രമമാണ്. ദൈവം ലോകം പരിപാലിക്കുന്നു, നമ്മുടെ ഉൽപ്പാദനക്ഷമതയല്ല. ശബ്ബത്ത് ക്രിസ്തുവിലേക്ക് — നമ്മുടെ യഥാർഥ വിശ്രാന്തിയിലേക്ക് — ചൂണ്ടുന്നു.',
   'ആത്മീയ അനുശാസനങ്ങൾ')
ON CONFLICT (topic_id, language_code) DO NOTHING;


-- =====================================================
-- PART 5: Re-link Work & Vocation path (019) to new topic IDs
-- =====================================================

UPDATE learning_path_topics
SET topic_id = 'ab190000-e29b-41d4-a716-446655440001'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
  AND topic_id = 'ab400000-e29b-41d4-a716-446655440001';

UPDATE learning_path_topics
SET topic_id = 'ab190000-e29b-41d4-a716-446655440002'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
  AND topic_id = 'ab400000-e29b-41d4-a716-446655440002';

UPDATE learning_path_topics
SET topic_id = 'ab190000-e29b-41d4-a716-446655440003'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
  AND topic_id = 'ab400000-e29b-41d4-a716-446655440003';

UPDATE learning_path_topics
SET topic_id = 'ab190000-e29b-41d4-a716-446655440004'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
  AND topic_id = 'ab400000-e29b-41d4-a716-446655440004';

UPDATE learning_path_topics
SET topic_id = 'ab190000-e29b-41d4-a716-446655440005'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
  AND topic_id = 'ab400000-e29b-41d4-a716-446655440005';


-- =====================================================
-- Verification
-- =====================================================

DO $$
DECLARE
  crux_en_title  TEXT;
  crux_hi_title  TEXT;
  crux_ml_title  TEXT;
  work_en_title  TEXT;
  work_path_topic UUID;
BEGIN
  -- Check Crucifixion topic 1 English title
  SELECT title INTO crux_en_title
  FROM recommended_topics
  WHERE id = 'ab400000-e29b-41d4-a716-446655440001';
  ASSERT crux_en_title = 'The Last Supper',
    'Crucifixion topic 1 English title wrong: ' || crux_en_title;

  -- Check Crucifixion topic 1 Hindi title
  SELECT title INTO crux_hi_title
  FROM recommended_topics_translations
  WHERE topic_id = 'ab400000-e29b-41d4-a716-446655440001' AND language_code = 'hi';
  ASSERT crux_hi_title = 'अंतिम भोज',
    'Crucifixion topic 1 Hindi title wrong: ' || crux_hi_title;

  -- Check Crucifixion topic 1 Malayalam title
  SELECT title INTO crux_ml_title
  FROM recommended_topics_translations
  WHERE topic_id = 'ab400000-e29b-41d4-a716-446655440001' AND language_code = 'ml';
  ASSERT crux_ml_title = 'അന്ത്യ അത്താഴം',
    'Crucifixion topic 1 Malayalam title wrong: ' || crux_ml_title;

  -- Check new Work topic exists
  SELECT title INTO work_en_title
  FROM recommended_topics
  WHERE id = 'ab190000-e29b-41d4-a716-446655440001';
  ASSERT work_en_title = 'Work Before and After the Fall',
    'Work topic ab190000...001 not found or wrong title: ' || COALESCE(work_en_title, 'NULL');

  -- Check Work path now points to new IDs
  SELECT topic_id INTO work_path_topic
  FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000019'
    AND topic_id = 'ab190000-e29b-41d4-a716-446655440001';
  ASSERT work_path_topic IS NOT NULL,
    'Work path (019) not re-linked to new topic ID ab190000...001';

  RAISE NOTICE 'Crucifixion topics fix verified: English corrected, Hindi/ML intact, Work path re-linked.';
END $$;

COMMIT;
