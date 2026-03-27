-- -------------------------------------------------------
-- Fix: Parables (031) and SOM (032) UUID collisions with Spiritual Warfare (016) and Church (017)
-- -------------------------------------------------------
-- PROBLEM:
--   migration 20260223000001 created:
--     ab100000..001-003 for Spiritual Warfare path (016) — "Who Is Satan?", "Armor of God", "Victory in Christ"
--     ab200000..001-002 for The Local Church path (017) — "Church Leadership", "Church Discipline"
--   migration 20260313000001 tried to reuse those same IDs for Parables (026/031) and SOM (027/032)
--   with ON CONFLICT DO NOTHING — silently skipped, leaving Spiritual Warfare / Church English content.
--   migration 20260316000003 already added correct Parables Hi/ML for ab100000..001-003
--   and correct SOM Hi/ML for ab200000..001-002.
--   Result: English shows wrong (Spiritual Warfare / Church) content in Parables and SOM paths.
--
-- FIX:
--   1. UPDATE ab100000..001-003 English to correct Parables topics 1-3 content
--   2. UPDATE ab200000..001-002 English to correct SOM topics 1-2 content
--   3. INSERT new b0160000..001-003 for displaced Spiritual Warfare topics
--   4. INSERT Hi/ML translations for b0160000..001-003
--   5. UPDATE learning_path_topics for path 016 to use b0160000 IDs
--   6. INSERT new b0170000..001-002 for displaced Church topics
--   7. INSERT Hi/ML translations for b0170000..001-002
--   8. UPDATE learning_path_topics for path 017 to use b0170000 IDs
-- -------------------------------------------------------

-- -------------------------------------------------------
-- STEP 1: Fix English base content for ab100000..001-003 → Parables topics 1-3
-- (Hi/ML translations already correct — updated by 20260316000003)
-- -------------------------------------------------------
UPDATE recommended_topics SET
  title        = 'The Sower and the Soils',
  description  = 'Jesus opens his great parable chapter with a story that is itself about how the gospel is received. The four soils reveal four kinds of responses to God''s Word: hardness, shallow enthusiasm, competing desires, and fruitful faith. This parable holds up a mirror to every hearer of the gospel and asks: what kind of soil are you?',
  category     = 'Foundations of Faith',
  tags         = ARRAY['parables', 'gospel', 'hearing', 'discipleship'],
  display_order = 301
WHERE id = 'ab100000-e29b-41d4-a716-446655440001';

UPDATE recommended_topics SET
  title        = 'The Wheat and the Weeds',
  description  = 'In a world where true and false disciples grow side by side, this parable warns against premature human judgment and assures that God will sort his harvest at the end. Final judgment belongs to God alone — not to those who would uproot the weeds and damage the wheat in the process. Patience and trust in divine justice mark the kingdom citizen.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['parables', 'judgment', 'kingdom', 'patience'],
  display_order = 302
WHERE id = 'ab100000-e29b-41d4-a716-446655440002';

UPDATE recommended_topics SET
  title        = 'The Mustard Seed',
  description  = 'The kingdom of God begins like the smallest of seeds — a peasant preacher from Galilee, twelve followers, a borrowed upper room. Yet from such unlikely beginnings, the kingdom grows into something large enough to shelter all who come. This parable invites faith in God''s sovereign work despite humble appearances.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['parables', 'kingdom', 'growth', 'faith'],
  display_order = 303
WHERE id = 'ab100000-e29b-41d4-a716-446655440003';

-- -------------------------------------------------------
-- STEP 2: Fix English base content for ab200000..001-002 → SOM topics 1-2
-- (Hi/ML translations already correct — updated by 20260316000003)
-- -------------------------------------------------------
UPDATE recommended_topics SET
  title        = 'The Beatitudes',
  description  = 'The Sermon on the Mount opens with counter-cultural blessings that overturn every expectation of the good life. The poor in spirit, the mourning, the meek, the hungry, the merciful, the pure, the peacemakers, and the persecuted are the ones Jesus calls blessed. These are not conditions to achieve but descriptions of the character God produces in those who are his.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['sermon on the mount', 'beatitudes', 'kingdom', 'character'],
  display_order = 329
WHERE id = 'ab200000-e29b-41d4-a716-446655440001';

UPDATE recommended_topics SET
  title        = 'Salt and Light',
  description  = 'Followers of Jesus are called to be salt that preserves and light that cannot be hidden. These are not commands to try harder to be influential — they are declarations of what kingdom people already are by grace. The call is not to lose saltiness through assimilation or hide the light through fear, but to let transformed lives shine for the glory of the Father.',
  category     = 'Foundations of Faith',
  tags         = ARRAY['sermon on the mount', 'witness', 'discipleship', 'influence'],
  display_order = 330
WHERE id = 'ab200000-e29b-41d4-a716-446655440002';

-- -------------------------------------------------------
-- STEP 3: INSERT new b0160000..001-003 for displaced Spiritual Warfare topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('b0160000-e29b-41d4-a716-446655440001', 'Who Is Satan and How Does He Operate?',
   'Scripture is neither silent about Satan nor obsessed with him — it gives us a clear, sober picture of our enemy. Study who Satan is, how he fell, what his tactics are (accusation, deception, temptation), and the limits of his power under God''s sovereign rule. Understanding the enemy is the first step to standing firm against him.',
   'Christian Living', ARRAY['satan', 'devil', 'spiritual warfare', 'deception'], 251, 50),

  ('b0160000-e29b-41d4-a716-446655440002', 'The Armor of God',
   'Ephesians 6 describes six pieces of spiritual armor that equip believers for the daily battle: truth, righteousness, the gospel, faith, salvation, and the Word of God. This study unpacks each piece practically — what it means to put it on, how it protects, and why every element points back to Jesus Christ as our ultimate warrior and defender.',
   'Spiritual Disciplines', ARRAY['armor of god', 'ephesians 6', 'prayer', 'warfare'], 252, 50),

  ('b0160000-e29b-41d4-a716-446655440003', 'Victory in Christ',
   'The decisive battle has already been won — at the cross and the empty tomb, Jesus disarmed the powers and authorities, making a public spectacle of them. Study what it means to live from victory rather than toward it, how the resurrection changes our position in spiritual warfare, and why believers can resist the devil with confident faith.',
   'Foundations of Faith', ARRAY['victory', 'resurrection', 'cross', 'spiritual warfare'], 253, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- STEP 4: INSERT Hi/ML translations for b0160000..001-003 (Spiritual Warfare)
-- -------------------------------------------------------
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES

  ('b0160000-e29b-41d4-a716-446655440001', 'hi',
   'शैतान कौन है और वह कैसे काम करता है?',
   'पवित्रशास्त्र शैतान के बारे में न तो चुप है और न ही उसके प्रति आसक्त — वह हमें हमारे शत्रु की स्पष्ट, संयमित तस्वीर देता है। शैतान कौन है, वह कैसे गिरा, उसकी रणनीतियाँ क्या हैं (आरोप, धोखा, प्रलोभन), और परमेश्वर की संप्रभु सत्ता के अधीन उसकी शक्ति की सीमाएँ क्या हैं — इसका अध्ययन करें। शत्रु को जानना उसके विरुद्ध दृढ़ खड़े रहने का पहला कदम है।',
   'Christian Living'),

  ('b0160000-e29b-41d4-a716-446655440001', 'ml',
   'സാത്താൻ ആരാണ്, അദ്ദേഹം എങ്ങനെ പ്രവർത്തിക്കുന്നു?',
   'തിരുവചനം സാത്താനെ കുറിച്ച് മൗനം ആകരുത്, ബാദ്ധ്യത ആകരുത് — ശത്രുവിന്റെ വ്യക്തവും ശാന്തവുമായ ചിത്രം നൽകുന്നു. സാത്താൻ ആര്, എങ്ങനെ വീണു, തന്ത്രങ്ങൾ (ആരോപണ, ചതി, പ്രലോഭ), ദൈവ-പരമ-സ്ഥൈര്യ-കീഴ് ശക്തി-പരിധി — ഇത് പഠിക്കുക. ശത്രു-അറിവ്, ദൃഢ-നിൽ-ആദ്യ-ചുവട്.',
   'Christian Living'),

  ('b0160000-e29b-41d4-a716-446655440002', 'hi',
   'परमेश्वर का कवच',
   'इफिसियों 6 आत्मिक कवच के छः टुकड़ों का वर्णन करता है जो विश्वासियों को दैनिक युद्ध के लिए सुसज्जित करते हैं: सत्य, धार्मिकता, सुसमाचार, विश्वास, उद्धार, और परमेश्वर का वचन। यह अध्ययन प्रत्येक टुकड़े को व्यावहारिक रूप से खोलता है — इसे पहनने का क्या अर्थ है, यह कैसे सुरक्षित करता है, और क्यों हर तत्व यीशु मसीह की ओर इशारा करता है जो हमारे परम योद्धा और रक्षक हैं।',
   'Spiritual Disciplines'),

  ('b0160000-e29b-41d4-a716-446655440002', 'ml',
   'ദൈവത്തിന്റെ ആയുധവർഗ്ഗം',
   'എഫേ. 6: ദൈനിക-യുദ്ധ-സജ്ജ ആറ് ആത്മ-ആയുധ: സത്യ, നീതി, സുവിശേഷ, വിശ്വ, രക്ഷ, ദൈവ-വചന. ഓരോ ആയുധ — അണിയൽ-അർത്ഥ, സംര-ക്ഷ-ഉദ്ദേ, ഓരോ ഘട്ടം ക്രിസ്തുവിലേക്ക് — ഇത് ഈ പഠനം ഉൾക്കൊള്ളും. ക്രിസ്തു നമ്മ-പരമ-യോദ്ധ-രക്ഷക.',
   'Spiritual Disciplines'),

  ('b0160000-e29b-41d4-a716-446655440003', 'hi',
   'मसीह में विजय',
   'निर्णायक युद्ध पहले ही जीत लिया गया है — क्रूस और खाली कब्र पर, यीशु ने शक्तियों और अधिकारों को निरस्त्र कर दिया, उन्हें सार्वजनिक रूप से लज्जित किया। इसका क्या अर्थ है कि विजय की ओर जाने के बजाय विजय से जिएं, पुनरुत्थान हमारी आत्मिक युद्ध में स्थिति को कैसे बदलता है, और विश्वासी आत्मविश्वास के साथ शैतान का विरोध क्यों कर सकते हैं — इसका अध्ययन करें।',
   'Foundations of Faith'),

  ('b0160000-e29b-41d4-a716-446655440003', 'ml',
   'ക്രിസ്തുവിൽ ജയം',
   'നിർണ്ണായക-യുദ്ധ ഇതിനകം ജയ — കുരിശ്-ശൂന്യ-കല്ലറ, യേശു ആധിപ-ബല-നിർ, ജനം-മധ്യ-ലജ്ജ. ജയ-ദിശ-ജീവ-ഒഴിക, ജയ-നിന്ന്-ജീവ — ഇത് അർത്ഥ. പുനരുത്ഥ-നമ്മ-ആത്മ-യുദ്ധ-നില-മാറ്റ, ദൃഢ-വിശ്വ-സ്ഥൈര്യ-ചെ-പ്രലോഭ-നേരി — ഇത് ഈ പഠനം ഉൾക്കൊള്ളും.',
   'Foundations of Faith')

ON CONFLICT (topic_id, language_code) DO NOTHING;

-- -------------------------------------------------------
-- STEP 5: Re-link path 016 (Spiritual Warfare) to new b0160000 IDs
-- -------------------------------------------------------
UPDATE learning_path_topics
  SET topic_id = 'b0160000-e29b-41d4-a716-446655440001'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000016'
    AND topic_id = 'ab100000-e29b-41d4-a716-446655440001';

UPDATE learning_path_topics
  SET topic_id = 'b0160000-e29b-41d4-a716-446655440002'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000016'
    AND topic_id = 'ab100000-e29b-41d4-a716-446655440002';

UPDATE learning_path_topics
  SET topic_id = 'b0160000-e29b-41d4-a716-446655440003'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000016'
    AND topic_id = 'ab100000-e29b-41d4-a716-446655440003';

-- -------------------------------------------------------
-- STEP 6: INSERT new b0170000..001-002 for displaced Church topics
-- -------------------------------------------------------
INSERT INTO recommended_topics (id, title, description, category, tags, display_order, xp_value) VALUES

  ('b0170000-e29b-41d4-a716-446655440001', 'Church Leadership and Authority',
   'The New Testament describes a structured community led by elders/pastors and deacons — servant-leaders who shepherd, teach, and protect the flock. Study the biblical qualifications for church leadership, the nature of spiritual authority, and how godly leadership differs from worldly power structures. Healthy churches have healthy leadership.',
   'Church & Community', ARRAY['church leadership', 'elders', 'pastors', 'authority'], 261, 50),

  ('b0170000-e29b-41d4-a716-446655440002', 'Church Discipline and Restoration',
   'One of the most misunderstood and neglected practices in modern Christianity, church discipline is actually an act of love — protecting the community and pursuing the restoration of a wandering member. Study Matthew 18 and 1 Corinthians 5, understand the goal of restoration over punishment, and see how discipline reflects the gospel''s seriousness about sin and grace.',
   'Church & Community', ARRAY['church discipline', 'restoration', 'accountability', 'community'], 262, 50)

ON CONFLICT (id) DO NOTHING;

-- -------------------------------------------------------
-- STEP 7: INSERT Hi/ML translations for b0170000..001-002 (Church)
-- -------------------------------------------------------
INSERT INTO recommended_topics_translations (topic_id, language_code, title, description, category) VALUES

  ('b0170000-e29b-41d4-a716-446655440001', 'hi',
   'कलीसिया में नेतृत्व और अधिकार',
   'नया नियम एक संरचित समुदाय का वर्णन करता है जिसका नेतृत्व प्राचीनों/पास्टरों और सेवकों द्वारा किया जाता है — सेवक-नेता जो झुंड को चराते, सिखाते और बचाते हैं। कलीसिया नेतृत्व के लिए बाइबलीय योग्यताएं, आत्मिक अधिकार की प्रकृति, और ईश्वरीय नेतृत्व सांसारिक शक्ति संरचनाओं से कैसे भिन्न है — इसका अध्ययन करें। स्वस्थ कलीसियाओं में स्वस्थ नेतृत्व होता है।',
   'Church & Community'),

  ('b0170000-e29b-41d4-a716-446655440001', 'ml',
   'സഭ നേതൃത്വവും അധികാരവും',
   'പുതിയ നിയമം: ഇടയൻ-അധ്യ-ദ്രഷ്ടൻ-ദ്വാരം ഒരു ഘടിത-സഭ — ആട്ടിൻ-പറ്റ-ഇടയ-പഠ-സംര-ദ്രഷ്ടൻ. സഭ-നേതൃ-ബൈബിൾ-യോഗ്യ, ആത്മ-അധി-സ്വഭാ, ഈ-നേതൃ-ലൗ-ബല-ഘടന-ഭിന്ന — ഇത് പഠിക്കുക. ആരോഗ്യ-സഭ-ആരോഗ്യ-നേതൃ ആണ്.',
   'Church & Community'),

  ('b0170000-e29b-41d4-a716-446655440002', 'hi',
   'कलीसिया में अनुशासन और पुनःस्थापन',
   'आधुनिक ईसाईयत में सबसे अधिक गलतफहमी और उपेक्षित प्रथाओं में से एक, कलीसिया अनुशासन वास्तव में प्रेम का एक कार्य है — समुदाय की रक्षा करना और भटके हुए सदस्य की पुनःस्थापना की तलाश करना। मत्ती 18 और 1 कुरिन्थियों 5 का अध्ययन करें, सजा के बजाय पुनःस्थापना के लक्ष्य को समझें, और देखें कि अनुशासन पाप और अनुग्रह के प्रति सुसमाचार की गंभीरता को कैसे दर्शाता है।',
   'Church & Community'),

  ('b0170000-e29b-41d4-a716-446655440002', 'ml',
   'സഭ ശിക്ഷണവും പുനഃസ്ഥാപനവും',
   'ആധുനിക-ക്രൈസ്തവ ഏറ്റം-തെറ്റ്-ഗ്രഹ-അവഗണ-ആചാ: സഭ-ശിക്ഷ — ഇത് സ്നേ-പ്രവൃ. സഭ-സംര, ഭ്രഷ്ട-അംഗ-പുനഃ-പ്രാ — ഇത് ഉദ്ദേ. മത്ത. 18, 1 കൊ. 5 — ഇത് പഠ, ശിക്ഷ-ഒഴ-പുനഃ-ലക്ഷ്യ, ശിക്ഷ-പാ-അനുഗ്ര-സുവി-ഗൗ-പ്രതിഫ — ഇത് ഈ പഠനം ഉൾക്കൊള്ളും.',
   'Church & Community')

ON CONFLICT (topic_id, language_code) DO NOTHING;

-- -------------------------------------------------------
-- STEP 8: Re-link path 017 (The Local Church) to new b0170000 IDs
-- -------------------------------------------------------
UPDATE learning_path_topics
  SET topic_id = 'b0170000-e29b-41d4-a716-446655440001'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000017'
    AND topic_id = 'ab200000-e29b-41d4-a716-446655440001';

UPDATE learning_path_topics
  SET topic_id = 'b0170000-e29b-41d4-a716-446655440002'
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000017'
    AND topic_id = 'ab200000-e29b-41d4-a716-446655440002';

-- -------------------------------------------------------
-- VERIFICATION
-- -------------------------------------------------------
DO $$
DECLARE
  parables_path_id   uuid := 'aaa00000-0000-0000-0000-000000000031';
  som_path_id        uuid := 'aaa00000-0000-0000-0000-000000000032';
  sw_path_id         uuid := 'aaa00000-0000-0000-0000-000000000016';
  church_path_id     uuid := 'aaa00000-0000-0000-0000-000000000017';
  bad_count          int;
BEGIN
  -- Parables path: ab100000..001-003 should now have Parables (Foundations of Faith) content
  SELECT COUNT(*) INTO bad_count
  FROM recommended_topics
  WHERE id IN (
    'ab100000-e29b-41d4-a716-446655440001',
    'ab100000-e29b-41d4-a716-446655440002',
    'ab100000-e29b-41d4-a716-446655440003'
  ) AND category NOT IN ('Foundations of Faith');

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: % Parables topics still have wrong category', bad_count;
  END IF;

  -- SOM path: ab200000..001-002 should now have SOM (Foundations of Faith) content
  SELECT COUNT(*) INTO bad_count
  FROM recommended_topics
  WHERE id IN (
    'ab200000-e29b-41d4-a716-446655440001',
    'ab200000-e29b-41d4-a716-446655440002'
  ) AND category != 'Foundations of Faith';

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: % SOM topics still have wrong category', bad_count;
  END IF;

  -- Spiritual Warfare path should now link b0160000 IDs, not ab100000 IDs
  SELECT COUNT(*) INTO bad_count
  FROM learning_path_topics
  WHERE learning_path_id = sw_path_id
    AND topic_id IN (
      'ab100000-e29b-41d4-a716-446655440001',
      'ab100000-e29b-41d4-a716-446655440002',
      'ab100000-e29b-41d4-a716-446655440003'
    );

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: Spiritual Warfare path still links % ab100000 topics', bad_count;
  END IF;

  -- Church path should now link b0170000 IDs, not ab200000 IDs
  SELECT COUNT(*) INTO bad_count
  FROM learning_path_topics
  WHERE learning_path_id = church_path_id
    AND topic_id IN (
      'ab200000-e29b-41d4-a716-446655440001',
      'ab200000-e29b-41d4-a716-446655440002'
    );

  IF bad_count > 0 THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: Church path still links % ab200000 topics', bad_count;
  END IF;

  RAISE NOTICE 'VERIFICATION PASSED: Parables and SOM UUID collisions fixed successfully';
END $$;
