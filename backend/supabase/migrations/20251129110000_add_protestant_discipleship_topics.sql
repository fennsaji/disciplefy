-- Migration: Add Essential Protestant Discipleship Topics
-- Purpose: Fill critical gaps for comprehensive believer training
-- Date: 2025-11-29
--
-- This migration adds 13 new topics covering:
-- 1. Identity in Christ (Foundations)
-- 2. Understanding God's Grace (Foundations)
-- 3. Spiritual Warfare (Christian Life)
-- 4. Dealing with Doubt (Christian Life)
-- 5. Baptism and Communion (Church & Community)
-- 6. How to Study the Bible (Spiritual Disciplines)
-- 7. Hearing God's Voice (Spiritual Disciplines)
-- 8. Faith and Science (Apologetics)
-- 9. Singleness and Contentment (Family & Relationships)
-- 10. Workplace as Mission (Mission & Service)
-- 11. The Return of Christ (NEW CATEGORY: Hope & Future)
-- 12. Heaven and Eternal Life (Hope & Future)
-- 13. Living by Faith, Not Feelings (Discipleship & Growth)

BEGIN;

-- =============================================================================
-- PART 1: ADD NEW RECOMMENDED TOPICS
-- =============================================================================

-- New topic IDs follow the pattern: 999e8400-e29b-41d4-a716-4466554400XX for new additions
-- and AAA/BBB patterns for new category

-- Foundations of Faith - 2 new topics
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('111e8400-e29b-41d4-a716-446655440007', 'Your Identity in Christ',
   'Discover who you are as a child of God - a new creation, forgiven, loved, and empowered by the Holy Spirit.',
   'Foundations of Faith',
   ARRAY['identity', 'new creation', 'child of god', 'freedom'], 43),
  ('111e8400-e29b-41d4-a716-446655440008', 'Understanding God''s Grace',
   'Learn the transforming power of grace - unmerited favor that saves us and empowers holy living without legalism.',
   'Foundations of Faith',
   ARRAY['grace', 'salvation', 'freedom', 'legalism'], 44)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Christian Life - 2 new topics
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('222e8400-e29b-41d4-a716-446655440007', 'Spiritual Warfare',
   'Understanding the spiritual battle, putting on the armor of God, and walking in victory through Christ.',
   'Christian Life',
   ARRAY['spiritual warfare', 'armor of god', 'victory', 'enemy'], 45),
  ('222e8400-e29b-41d4-a716-446655440008', 'Dealing with Doubt and Fear',
   'How to overcome doubt and fear through Scripture, prayer, and trusting God''s faithfulness.',
   'Christian Life',
   ARRAY['doubt', 'fear', 'faith', 'trust'], 46)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Church & Community - 1 new topic
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('333e8400-e29b-41d4-a716-446655440006', 'Baptism and Communion',
   'Understanding the meaning and importance of the two ordinances given by Christ to the church.',
   'Church & Community',
   ARRAY['baptism', 'communion', 'lords supper', 'ordinances'], 47)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Spiritual Disciplines - 2 new topics
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('555e8400-e29b-41d4-a716-446655440006', 'How to Study the Bible',
   'Practical methods for reading, understanding, and applying Scripture effectively in your daily life.',
   'Spiritual Disciplines',
   ARRAY['bible study', 'hermeneutics', 'scripture', 'application'], 48),
  ('555e8400-e29b-41d4-a716-446655440007', 'Hearing God''s Voice',
   'Learning to discern God''s guidance through Scripture, prayer, the Holy Spirit, and godly counsel.',
   'Spiritual Disciplines',
   ARRAY['hearing god', 'guidance', 'discernment', 'holy spirit'], 49)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Apologetics - 1 new topic
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('666e8400-e29b-41d4-a716-446655440006', 'Faith and Science',
   'Exploring how faith and science complement each other, and evidence for God in creation.',
   'Apologetics & Defense of Faith',
   ARRAY['faith', 'science', 'creation', 'evidence'], 50)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Family & Relationships - 1 new topic
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('777e8400-e29b-41d4-a716-446655440006', 'Singleness and Contentment',
   'Finding purpose and contentment in singleness while trusting God''s timing and plan for your life.',
   'Family & Relationships',
   ARRAY['singleness', 'contentment', 'waiting', 'purpose'], 51)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Mission & Service - 1 new topic
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('888e8400-e29b-41d4-a716-446655440006', 'Workplace as Mission',
   'Being salt and light in your workplace - living out your faith and making an impact for Christ at work.',
   'Mission & Service',
   ARRAY['workplace', 'mission', 'salt and light', 'witness'], 52)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- Discipleship & Growth - 1 new topic
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('444e8400-e29b-41d4-a716-446655440006', 'Living by Faith, Not Feelings',
   'Learning to walk by faith and trust God''s promises even when emotions and circumstances are difficult.',
   'Discipleship & Growth',
   ARRAY['faith', 'feelings', 'trust', 'perseverance'], 53)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- NEW CATEGORY: Hope & Future - 2 new topics
INSERT INTO recommended_topics (id, title, description, category, tags, display_order)
VALUES
  ('999e8400-e29b-41d4-a716-446655440001', 'The Return of Christ',
   'Understanding the blessed hope of Jesus'' second coming and how it shapes our daily living.',
   'Hope & Future',
   ARRAY['second coming', 'return of christ', 'hope', 'eschatology'], 54),
  ('999e8400-e29b-41d4-a716-446655440002', 'Heaven and Eternal Life',
   'What the Bible teaches about heaven, eternity, and the glorious future that awaits believers.',
   'Hope & Future',
   ARRAY['heaven', 'eternal life', 'eternity', 'resurrection'], 55)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  tags = EXCLUDED.tags;

-- =============================================================================
-- PART 2: ADD HINDI TRANSLATIONS
-- =============================================================================

INSERT INTO recommended_topics_translations (topic_id, lang_code, category, title, description)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007', 'hi', 'विश्वास की नींव', 'मसीह में आपकी पहचान',
   'जानें कि आप परमेश्वर की संतान के रूप में कौन हैं - एक नई सृष्टि, क्षमा किया हुआ, प्रेमित, और पवित्र आत्मा द्वारा सशक्त।'),
  ('111e8400-e29b-41d4-a716-446655440008', 'hi', 'विश्वास की नींव', 'परमेश्वर की कृपा को समझना',
   'कृपा की परिवर्तनकारी शक्ति को जानें - अयोग्य अनुग्रह जो हमें बचाता है और कानूनवाद के बिना पवित्र जीवन जीने में सक्षम बनाता है।'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'hi', 'मसीही जीवन', 'आत्मिक युद्ध',
   'आत्मिक युद्ध को समझना, परमेश्वर का हथियार पहनना, और मसीह के माध्यम से विजय में चलना।'),
  ('222e8400-e29b-41d4-a716-446655440008', 'hi', 'मसीही जीवन', 'संदेह और भय से निपटना',
   'वचन, प्रार्थना, और परमेश्वर की विश्वासयोग्यता पर भरोसा करके संदेह और भय पर कैसे विजय पाएं।'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'hi', 'कलीसिया और समुदाय', 'बपतिस्मा और प्रभु भोज',
   'मसीह द्वारा कलीसिया को दिए गए दो अनुष्ठानों के अर्थ और महत्व को समझना।'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'hi', 'आत्मिक अनुशासन', 'बाइबल का अध्ययन कैसे करें',
   'अपने दैनिक जीवन में शास्त्र को प्रभावी ढंग से पढ़ने, समझने और लागू करने के व्यावहारिक तरीके।'),
  ('555e8400-e29b-41d4-a716-446655440007', 'hi', 'आत्मिक अनुशासन', 'परमेश्वर की आवाज सुनना',
   'वचन, प्रार्थना, पवित्र आत्मा, और भक्तिमय सलाह के माध्यम से परमेश्वर के मार्गदर्शन को समझना सीखना।'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'hi', 'धर्मशास्त्र और विश्वास की रक्षा', 'विश्वास और विज्ञान',
   'कैसे विश्वास और विज्ञान एक दूसरे के पूरक हैं, और सृष्टि में परमेश्वर के लिए प्रमाण खोजना।'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'hi', 'परिवार और रिश्ते', 'एकलता और संतोष',
   'एकलता में उद्देश्य और संतोष खोजना जबकि अपने जीवन के लिए परमेश्वर की समय और योजना पर भरोसा करना।'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'hi', 'मिशन और सेवा', 'कार्यस्थल मिशन के रूप में',
   'अपने कार्यस्थल में नमक और ज्योति बनना - अपने विश्वास को जीना और काम पर मसीह के लिए प्रभाव डालना।'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'hi', 'शिष्यत्व और विकास', 'विश्वास से जीना, भावनाओं से नहीं',
   'विश्वास से चलना और परमेश्वर की प्रतिज्ञाओं पर भरोसा करना सीखना, भले ही भावनाएं और परिस्थितियां कठिन हों।'),

  -- Hope & Future (NEW CATEGORY)
  ('999e8400-e29b-41d4-a716-446655440001', 'hi', 'आशा और भविष्य', 'मसीह की वापसी',
   'यीशु के दूसरे आगमन की धन्य आशा को समझना और यह हमारे दैनिक जीवन को कैसे आकार देता है।'),
  ('999e8400-e29b-41d4-a716-446655440002', 'hi', 'आशा और भविष्य', 'स्वर्ग और अनंत जीवन',
   'बाइबल स्वर्ग, अनंत काल, और विश्वासियों के लिए प्रतीक्षारत महिमामय भविष्य के बारे में क्या सिखाती है।')
ON CONFLICT (topic_id, lang_code) DO UPDATE SET
  category = EXCLUDED.category,
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- =============================================================================
-- PART 3: ADD MALAYALAM TRANSLATIONS
-- =============================================================================

INSERT INTO recommended_topics_translations (topic_id, lang_code, category, title, description)
VALUES
  -- Foundations of Faith
  ('111e8400-e29b-41d4-a716-446655440007', 'ml', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ', 'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം',
   'നിങ്ങൾ ദൈവത്തിന്റെ മകനായി/മകളായി ആരാണെന്ന് കണ്ടെത്തുക - ഒരു പുതിയ സൃഷ്ടി, ക്ഷമിക്കപ്പെട്ട, സ്നേഹിക്കപ്പെട്ട, പരിശുദ്ധാത്മാവിനാൽ ശാക്തീകരിക്കപ്പെട്ട.'),
  ('111e8400-e29b-41d4-a716-446655440008', 'ml', 'വിശ്വാസത്തിന്റെ അടിത്തറകൾ', 'ദൈവത്തിന്റെ കൃപ മനസ്സിലാക്കുക',
   'കൃപയുടെ രൂപാന്തരപ്പെടുത്തുന്ന ശക്തി പഠിക്കുക - നമ്മെ രക്ഷിക്കുകയും നിയമവാദമില്ലാതെ വിശുദ്ധ ജീവിതം നയിക്കാൻ ശക്തിപ്പെടുത്തുകയും ചെയ്യുന്ന അയോഗ്യമായ അനുഗ്രഹം.'),

  -- Christian Life
  ('222e8400-e29b-41d4-a716-446655440007', 'ml', 'ക്രൈസ്തവ ജീവിതം', 'ആത്മീയ യുദ്ധം',
   'ആത്മീയ യുദ്ധം മനസ്സിലാക്കുക, ദൈവത്തിന്റെ കവചം ധരിക്കുക, ക്രിസ്തുവിലൂടെ വിജയത്തിൽ നടക്കുക.'),
  ('222e8400-e29b-41d4-a716-446655440008', 'ml', 'ക്രൈസ്തവ ജീവിതം', 'സംശയവും ഭയവും കൈകാര്യം ചെയ്യുക',
   'തിരുവെഴുത്ത്, പ്രാർത്ഥന, ദൈവത്തിന്റെ വിശ്വസ്തതയിൽ ആശ്രയിക്കുന്നതിലൂടെ സംശയവും ഭയവും എങ്ങനെ മറികടക്കാം.'),

  -- Church & Community
  ('333e8400-e29b-41d4-a716-446655440006', 'ml', 'സഭയും സമൂഹവും', 'സ്നാനവും കർത്താവിന്റെ അത്താഴവും',
   'ക്രിസ്തു സഭയ്ക്ക് നൽകിയ രണ്ട് കൽപ്പനകളുടെ അർത്ഥവും പ്രാധാന്യവും മനസ്സിലാക്കുക.'),

  -- Spiritual Disciplines
  ('555e8400-e29b-41d4-a716-446655440006', 'ml', 'ആത്മീയ അനുശാസനം', 'ബൈബിൾ എങ്ങനെ പഠിക്കാം',
   'നിങ്ങളുടെ ദൈനംദിന ജീവിതത്തിൽ തിരുവെഴുത്തുകൾ ഫലപ്രദമായി വായിക്കാനും മനസ്സിലാക്കാനും പ്രയോഗിക്കാനുമുള്ള പ്രായോഗിക മാർഗങ്ങൾ.'),
  ('555e8400-e29b-41d4-a716-446655440007', 'ml', 'ആത്മീയ അനുശാസനം', 'ദൈവത്തിന്റെ ശബ്ദം കേൾക്കുക',
   'തിരുവെഴുത്ത്, പ്രാർത്ഥന, പരിശുദ്ധാത്മാവ്, ഭക്തിയുള്ള ഉപദേശം എന്നിവയിലൂടെ ദൈവത്തിന്റെ മാർഗദർശനം തിരിച്ചറിയാൻ പഠിക്കുക.'),

  -- Apologetics
  ('666e8400-e29b-41d4-a716-446655440006', 'ml', 'ക്ഷമാപണവും വിശ്വാസത്തിന്റെ പ്രതിരോധവും', 'വിശ്വാസവും ശാസ്ത്രവും',
   'വിശ്വാസവും ശാസ്ത്രവും എങ്ങനെ പരസ്പരം പൂർത്തീകരിക്കുന്നു, സൃഷ്ടിയിൽ ദൈവത്തിനുള്ള തെളിവുകൾ എന്നിവ പര്യവേക്ഷണം ചെയ്യുക.'),

  -- Family & Relationships
  ('777e8400-e29b-41d4-a716-446655440006', 'ml', 'കുടുംബവും ബന്ധങ്ങളും', 'ഏകാന്തതയും സംതൃപ്തിയും',
   'നിങ്ങളുടെ ജീവിതത്തിനായുള്ള ദൈവത്തിന്റെ സമയത്തെയും പദ്ധതിയെയും വിശ്വസിക്കുമ്പോൾ ഏകാന്തതയിൽ ഉദ്ദേശ്യവും സംതൃപ്തിയും കണ്ടെത്തുക.'),

  -- Mission & Service
  ('888e8400-e29b-41d4-a716-446655440006', 'ml', 'മിഷനും സേവനവും', 'ജോലിസ്ഥലം മിഷനായി',
   'നിങ്ങളുടെ ജോലിസ്ഥലത്ത് ഉപ്പും വെളിച്ചവുമാകുക - നിങ്ങളുടെ വിശ്വാസം ജീവിക്കുകയും ജോലിസ്ഥലത്ത് ക്രിസ്തുവിനായി സ്വാധീനം ചെലുത്തുകയും ചെയ്യുക.'),

  -- Discipleship & Growth
  ('444e8400-e29b-41d4-a716-446655440006', 'ml', 'ശിഷ്യത്വവും വളർച്ചയും', 'വിശ്വാസത്താൽ ജീവിക്കുക, വികാരങ്ങളാൽ അല്ല',
   'വികാരങ്ങളും സാഹചര്യങ്ങളും ബുദ്ധിമുട്ടായിരിക്കുമ്പോൾ പോലും വിശ്വാസത്താൽ നടക്കാനും ദൈവത്തിന്റെ വാഗ്ദാനങ്ങളിൽ വിശ്വസിക്കാനും പഠിക്കുക.'),

  -- Hope & Future (NEW CATEGORY)
  ('999e8400-e29b-41d4-a716-446655440001', 'ml', 'പ്രത്യാശയും ഭാവിയും', 'ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്',
   'യേശുവിന്റെ രണ്ടാം വരവിന്റെ അനുഗ്രഹീത പ്രത്യാശ മനസ്സിലാക്കുക, അത് നമ്മുടെ ദൈനംദിന ജീവിതത്തെ എങ്ങനെ രൂപപ്പെടുത്തുന്നു.'),
  ('999e8400-e29b-41d4-a716-446655440002', 'ml', 'പ്രത്യാശയും ഭാവിയും', 'സ്വർഗവും നിത്യജീവനും',
   'സ്വർഗം, നിത്യത, വിശ്വാസികളെ കാത്തിരിക്കുന്ന മഹത്തായ ഭാവി എന്നിവയെക്കുറിച്ച് ബൈബിൾ എന്താണ് പഠിപ്പിക്കുന്നത്.')
ON CONFLICT (topic_id, lang_code) DO UPDATE SET
  category = EXCLUDED.category,
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- =============================================================================
-- PART 4: CREATE NEW LEARNING PATH - "Rooted in Christ"
-- =============================================================================
-- This path covers the foundational identity and grace topics

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000008',
  'rooted-in-christ',
  'Rooted in Christ',
  'Establish your foundation by understanding your identity in Christ, living by grace, and building unshakeable faith.',
  'park',
  '#10B981',
  21,
  'beginner',
  true,
  8
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Rooted in Christ (key foundational topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000008', '111e8400-e29b-41d4-a716-446655440007', 1, false),  -- Your Identity in Christ
  ('aaa00000-0000-0000-0000-000000000008', '111e8400-e29b-41d4-a716-446655440008', 2, true),   -- Understanding God's Grace (Milestone)
  ('aaa00000-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440008', 3, false),  -- Dealing with Doubt and Fear
  ('aaa00000-0000-0000-0000-000000000008', '444e8400-e29b-41d4-a716-446655440006', 4, false),  -- Living by Faith, Not Feelings
  ('aaa00000-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440007', 5, true)    -- Spiritual Warfare (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Rooted in Christ
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000008', 'hi', 'मसीह में जड़ित',
   'मसीह में अपनी पहचान को समझकर, कृपा से जीकर, और अडिग विश्वास बनाकर अपनी नींव स्थापित करें।'),
  ('aaa00000-0000-0000-0000-000000000008', 'ml', 'ക്രിസ്തുവിൽ വേരൂന്നിയ',
   'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം മനസ്സിലാക്കി, കൃപയാൽ ജീവിച്ച്, ഇളക്കമില്ലാത്ത വിശ്വാസം കെട്ടിപ്പടുത്ത് നിങ്ങളുടെ അടിത്തറ സ്ഥാപിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- PART 5: CREATE NEW LEARNING PATH - "Eternal Perspective"
-- =============================================================================
-- This path covers hope, eternity, and future glory

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000009',
  'eternal-perspective',
  'Eternal Perspective',
  'Gain hope and purpose by understanding God''s eternal plan - the return of Christ, heaven, and our glorious future.',
  'wb_sunny',
  '#F97316',
  14,
  'intermediate',
  false,
  9
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Eternal Perspective
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000009', '999e8400-e29b-41d4-a716-446655440001', 1, false),  -- The Return of Christ
  ('aaa00000-0000-0000-0000-000000000009', '999e8400-e29b-41d4-a716-446655440002', 2, true),   -- Heaven and Eternal Life (Milestone)
  ('aaa00000-0000-0000-0000-000000000009', '666e8400-e29b-41d4-a716-446655440005', 3, false),  -- Standing Firm in Persecution
  ('aaa00000-0000-0000-0000-000000000009', '444e8400-e29b-41d4-a716-446655440006', 4, true)    -- Living by Faith, Not Feelings (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Eternal Perspective
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000009', 'hi', 'अनंत दृष्टिकोण',
   'परमेश्वर की अनंत योजना को समझकर आशा और उद्देश्य प्राप्त करें - मसीह की वापसी, स्वर्ग, और हमारा महिमामय भविष्य।'),
  ('aaa00000-0000-0000-0000-000000000009', 'ml', 'നിത്യ വീക്ഷണം',
   'ദൈവത്തിന്റെ നിത്യ പദ്ധതി മനസ്സിലാക്കി പ്രത്യാശയും ഉദ്ദേശ്യവും നേടുക - ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്, സ്വർഗം, നമ്മുടെ മഹത്തായ ഭാവി.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- PART 6: ADD NEW TOPICS TO EXISTING LEARNING PATHS
-- =============================================================================

-- Add "Baptism and Communion" to "New Believer Essentials" (Path 1)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000001', '333e8400-e29b-41d4-a716-446655440006', 7, true)  -- Baptism and Communion (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Add "How to Study the Bible" and "Hearing God's Voice" to "Growing in Discipleship" (Path 2)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440006', 10, false), -- How to Study the Bible
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440007', 11, true)   -- Hearing God's Voice (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Add "Workplace as Mission" to "Serving & Mission" (Path 3)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440006', 9, false)  -- Workplace as Mission
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Add "Faith and Science" to "Defending Your Faith" (Path 4)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440006', 6, true)  -- Faith and Science (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Add "Singleness and Contentment" to "Faith & Family" (Path 5)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440006', 6, false)  -- Singleness and Contentment
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;


-- =============================================================================
-- PART 7: UPDATE TOTAL XP FOR ALL PATHS
-- =============================================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000001');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000002');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000003');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000004');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000005');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000006');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000007');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000008');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000009');


-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
DECLARE
  total_topics INT;
  total_paths INT;
  topics_in_paths INT;
BEGIN
  SELECT COUNT(*) INTO total_topics FROM recommended_topics WHERE is_active = true;
  SELECT COUNT(*) INTO total_paths FROM learning_paths WHERE is_active = true;
  SELECT COUNT(DISTINCT topic_id) INTO topics_in_paths FROM learning_path_topics;

  RAISE NOTICE '';
  RAISE NOTICE '=== Protestant Discipleship Topics Migration Summary ===';
  RAISE NOTICE 'Total active topics: %', total_topics;
  RAISE NOTICE 'Total active learning paths: %', total_paths;
  RAISE NOTICE 'Unique topics in paths: %', topics_in_paths;
  RAISE NOTICE '';

  -- List new topics
  RAISE NOTICE 'New topics added:';
  RAISE NOTICE '  - Your Identity in Christ (Foundations)';
  RAISE NOTICE '  - Understanding God''s Grace (Foundations)';
  RAISE NOTICE '  - Spiritual Warfare (Christian Life)';
  RAISE NOTICE '  - Dealing with Doubt and Fear (Christian Life)';
  RAISE NOTICE '  - Baptism and Communion (Church & Community)';
  RAISE NOTICE '  - How to Study the Bible (Spiritual Disciplines)';
  RAISE NOTICE '  - Hearing God''s Voice (Spiritual Disciplines)';
  RAISE NOTICE '  - Faith and Science (Apologetics)';
  RAISE NOTICE '  - Singleness and Contentment (Family & Relationships)';
  RAISE NOTICE '  - Workplace as Mission (Mission & Service)';
  RAISE NOTICE '  - Living by Faith, Not Feelings (Discipleship & Growth)';
  RAISE NOTICE '  - The Return of Christ (Hope & Future - NEW CATEGORY)';
  RAISE NOTICE '  - Heaven and Eternal Life (Hope & Future)';
  RAISE NOTICE '';
  RAISE NOTICE 'New learning paths added:';
  RAISE NOTICE '  - Rooted in Christ (identity, grace, spiritual warfare)';
  RAISE NOTICE '  - Eternal Perspective (hope, heaven, second coming)';
END $$;

COMMIT;
