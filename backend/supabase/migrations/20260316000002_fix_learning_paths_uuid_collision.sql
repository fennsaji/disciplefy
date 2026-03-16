-- =====================================================
-- Migration: Fix UUID Collision in Learning Paths v2
-- =====================================================
-- Root cause: new_learning_paths_v2.sql (2026-03-13) reused IDs 26-29
-- which were already taken by new_learning_paths.sql (2026-02-23):
--   26 = The Attributes of God
--   27 = Law, Grace & the Covenants
--   28 = Sin, Repentance & the Grace of God
--   29 = The Big Questions
-- The 4 v2 paths were silently skipped (ON CONFLICT DO NOTHING),
-- but their learning_path_topics rows were inserted, linking ab1/ab2/ab3/ab4
-- topics to the WRONG paths.
--
-- Fix:
--   1. Remove misplaced topic links from wrong paths (26-29)
--   2. Insert the 4 missing learning paths with new IDs (31-34)
--   3. Re-insert topic links with correct new path IDs
--   4. Insert translations for new paths
--   5. Recompute XP for new paths
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Remove misplaced learning_path_topics rows
--         (ab1=Parables linked to path 26, ab2=SotM to 27,
--          ab3=Romans to 28, ab4=CXR to 29)
-- =====================================================

DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000026'
  AND topic_id::text LIKE 'ab100000%';

DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000027'
  AND topic_id::text LIKE 'ab200000%';

DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000028'
  AND topic_id::text LIKE 'ab300000%';

DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000029'
  AND topic_id::text LIKE 'ab400000%';


-- =====================================================
-- STEP 2: Insert 4 missing learning paths with new IDs
-- =====================================================

-- Path 31: Jesus's Parables (was 26 in v2)
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000031',
  'jesus-parables',
  'Jesus''s Parables',
  'Jesus taught in parables — earthly stories with heavenly meanings. These 28 stories reveal the nature of God''s kingdom, the scandal of grace, the weight of judgment, and the radical demands of discipleship. From the Prodigal Son to the Sower, each parable holds up a mirror to the human heart.',
  'auto_stories', '#F59E0B', 42, 'intermediate', 'follower', 'standard', false, 31, 'Theology'
) ON CONFLICT (id) DO NOTHING;

-- Path 32: Sermon on the Mount (was 27 in v2)
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000032',
  'sermon-on-the-mount',
  'Sermon on the Mount',
  'In Matthew 5-7, Jesus delivers the most famous sermon ever preached — the constitution of the kingdom of God. From the Beatitudes to the Wise Builder, the Sermon reveals the ethics of the kingdom not as a new law to earn salvation but as the fruit of a heart transformed by grace. Study it carefully; it will not let you be comfortable.',
  'terrain', '#10B981', 30, 'intermediate', 'follower', 'standard', false, 32, 'Foundations'
) ON CONFLICT (id) DO NOTHING;

-- Path 33: Romans: The Gospel Unfolded (was 28 in v2)
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000033',
  'romans-gospel-unfolded',
  'Romans: The Gospel Unfolded',
  'Paul''s letter to the Romans is the most systematic exposition of the gospel in all of Scripture. Study it chapter by chapter: universal sin, justification by faith alone, union with Christ, life in the Spirit, sovereign election, Israel''s future, and the ethics of a transformed life. Romans will change how you understand everything.',
  'import_contacts', '#6366F1', 32, 'advanced', 'disciple', 'deep', false, 33, 'Growth'
) ON CONFLICT (id) DO NOTHING;

-- Path 34: The Crucifixion and Resurrection of Jesus (was 29 in v2)
INSERT INTO learning_paths (id, slug, title, description, icon_name, color, estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order, category)
VALUES (
  'aaa00000-0000-0000-0000-000000000034',
  'crucifixion-and-resurrection',
  'The Crucifixion and Resurrection of Jesus',
  'This is the center of Christian faith — the events that change everything. From the Last Supper to the Ascension, follow the story of Jesus''s arrest, trial, death, burial, and bodily resurrection through 16 studies. No other events in history carry this weight. Here is the gospel in its fullest form.',
  'brightness_5', '#EF4444', 24, 'beginner', 'seeker', 'standard', false, 34, 'Foundations'
) ON CONFLICT (id) DO NOTHING;


-- =====================================================
-- STEP 3: Re-insert learning_path_topics with correct IDs
-- =====================================================

-- Path 31: Jesus's Parables (28 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440001',  0, false),  -- The Sower and the Soils
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440002',  1, false),  -- The Wheat and the Weeds
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440003',  2, false),  -- The Mustard Seed
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440004',  3, false),  -- The Yeast
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440005',  4, false),  -- The Hidden Treasure
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440006',  5, false),  -- The Pearl of Great Value
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440007',  6, true),   -- The Net (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440008',  7, false),  -- The Lost Sheep
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440009',  8, false),  -- The Unmerciful Servant
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440010',  9, false),  -- The Workers in the Vineyard
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440011', 10, false),  -- The Two Sons
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440012', 11, false),  -- The Tenants
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440013', 12, false),  -- The Wedding Banquet
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440014', 13, true),   -- The Ten Virgins (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440015', 14, false),  -- The Talents
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440016', 15, false),  -- The Sheep and the Goats
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440017', 16, false),  -- The Growing Seed
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440018', 17, false),  -- The Good Samaritan
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440019', 18, false),  -- The Persistent Friend
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440020', 19, false),  -- The Rich Fool
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440021', 20, true),   -- The Barren Fig Tree (Milestone 3)
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440022', 21, false),  -- The Great Banquet
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440023', 22, false),  -- The Lost Coin
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440024', 23, false),  -- The Prodigal Son
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440025', 24, false),  -- The Dishonest Manager
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440026', 25, false),  -- The Rich Man and Lazarus
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440027', 26, false),  -- The Persistent Widow
  ('aaa00000-0000-0000-0000-000000000031', 'ab100000-e29b-41d4-a716-446655440028', 27, true)    -- The Pharisee and the Tax Collector (Milestone 4)
ON CONFLICT DO NOTHING;

-- Path 32: Sermon on the Mount (20 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440001',  0, false),  -- The Beatitudes
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440002',  1, false),  -- Salt and Light
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440003',  2, false),  -- Christ Fulfills the Law
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440004',  3, false),  -- Anger and Reconciliation
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440005',  4, false),  -- Purity of Heart
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440006',  5, false),  -- Divorce
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440007',  6, false),  -- Oaths and Integrity
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440008',  7, false),  -- Nonresistance: The Ethic of the Kingdom
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440009',  8, true),   -- Love Your Enemies (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440010',  9, false),  -- Giving in Secret
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440011', 10, false),  -- The Lord's Prayer
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440012', 11, false),  -- Fasting
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440013', 12, false),  -- Treasures in Heaven
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440014', 13, false),  -- Do Not Worry
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440015', 14, true),   -- Do Not Judge (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440016', 15, false),  -- Ask, Seek, Knock
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440017', 16, false),  -- The Narrow Gate
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440018', 17, false),  -- A Tree and Its Fruit
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440019', 18, false),  -- True and False Disciples
  ('aaa00000-0000-0000-0000-000000000032', 'ab200000-e29b-41d4-a716-446655440020', 19, true)    -- The Wise and Foolish Builders (Milestone 3)
ON CONFLICT DO NOTHING;

-- Path 33: Romans: The Gospel Unfolded (16 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440001',  0, false),  -- Romans 1: Power of the Gospel & Universal Guilt
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440002',  1, false),  -- Romans 2: God's Impartial Judgment
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440003',  2, false),  -- Romans 3: Righteousness Through Faith
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440004',  3, true),   -- Romans 4: Abraham, Father of Faith (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440005',  4, false),  -- Romans 5: Peace with God Through Christ
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440006',  5, false),  -- Romans 6: Dead to Sin, Alive in Christ
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440007',  6, false),  -- Romans 7: The Struggle with Sin and the Law
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440008',  7, true),   -- Romans 8: Life in the Spirit (Milestone 2)
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440009',  8, false),  -- Romans 9: God's Sovereign Election
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440010',  9, false),  -- Romans 10: Salvation for All Who Call
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440011', 10, false),  -- Romans 11: The Mystery of Israel's Future
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440012', 11, true),   -- Romans 12: Living Sacrifices (Milestone 3)
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440013', 12, false),  -- Romans 13: Governing Authorities & Debt of Love
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440014', 13, false),  -- Romans 14: Receiving One Another
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440015', 14, false),  -- Romans 15: United in Christ's Mission
  ('aaa00000-0000-0000-0000-000000000033', 'ab300000-e29b-41d4-a716-446655440016', 15, true)    -- Romans 16: Greetings & Community of Faith (Milestone 4)
ON CONFLICT DO NOTHING;

-- Path 34: The Crucifixion and Resurrection (16 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440001',  0, false),  -- The Last Supper
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440002',  1, false),  -- The Garden of Gethsemane
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440003',  2, false),  -- Betrayal and Arrest
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440004',  3, false),  -- Peter's Denial
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440005',  4, false),  -- Jesus Before the Sanhedrin
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440006',  5, false),  -- Jesus Before Pilate
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440007',  6, false),  -- The Crucifixion
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440008',  7, true),   -- The Death of Jesus (Milestone 1)
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440009',  8, false),  -- The Burial of Jesus
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440010',  9, false),  -- The Empty Tomb
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440011', 10, false),  -- Jesus Appears to Mary Magdalene
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440012', 11, false),  -- The Road to Emmaus
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440013', 12, false),  -- Jesus Appears to the Disciples
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440014', 13, false),  -- Thomas: Doubt and Belief
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440015', 14, false),  -- The Great Commission
  ('aaa00000-0000-0000-0000-000000000034', 'ab400000-e29b-41d4-a716-446655440016', 15, true)    -- The Ascension (Milestone 2)
ON CONFLICT DO NOTHING;


-- =====================================================
-- STEP 4: Insert translations for the 4 new paths
-- =====================================================

-- Path 31: Jesus's Parables
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000031', 'hi',
   'यीशु के दृष्टान्त',
   'यीशु ने दृष्टान्तों के माध्यम से परमेश्वर के राज्य के रहस्यों को प्रकट किया। खोए हुए पुत्र से लेकर बीज बोने वाले तक, ये 28 कहानियाँ अनुग्रह, न्याय और शिष्यता की गहरी सच्चाइयाँ उजागर करती हैं।'),
  ('aaa00000-0000-0000-0000-000000000031', 'ml',
   'യേശുവിന്റെ ഉപമകൾ',
   'യേശു ഉപമകളിലൂടെ ദൈവരാജ്യത്തിന്റെ രഹസ്യങ്ങൾ വെളിപ്പെടുത്തി. കാണാതായ പുത്രൻ മുതൽ വിതക്കാരൻ വരെ — ഈ 28 കഥകൾ കൃപ, ന്യായവിധി, ശിഷ്യത്വം എന്നിവയുടെ ആഴമേറിയ സത്യങ്ങൾ വെളിപ്പെടുത്തുന്നു.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- Path 32: Sermon on the Mount
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000032', 'hi',
   'पहाड़ी उपदेश',
   'मत्ती 5-7 में यीशु परमेश्वर के राज्य का संविधान देते हैं। धन्यवादिताओं से बुद्धिमान निर्माता तक — यह उपदेश नई व्यवस्था नहीं बल्कि कृपा से रूपांतरित हृदय का फल है। इसका अध्ययन करें; यह आपको वैसा नहीं रहने देगा जैसे आप थे।'),
  ('aaa00000-0000-0000-0000-000000000032', 'ml',
   'മലയിലെ പ്രസംഗം',
   'മത്തായി 5-7 ൽ യേശു ദൈവരാജ്യത്തിന്റെ ഭരണഘടന നൽകുന്നു. ഭാഗ്യോക്തികൾ മുതൽ ജ്ഞാനിയായ പണിക്കാരൻ വരെ — ഈ പ്രസംഗം നൂതന നിയമമല്ല, മറിച്ച് കൃപയാൽ മാറ്റിമറിക്കപ്പെട്ട ഹൃദയത്തിന്റെ ഫലമാണ്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- Path 33: Romans
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000033', 'hi',
   'रोमियों: सुसमाचार का प्रकाशन',
   'रोमियों पत्र पवित्रशास्त्र में सुसमाचार की सबसे व्यवस्थित व्याख्या है। 16 अध्यायों में पाएं: सार्वभौमिक पाप, विश्वास से धार्मिकता, मसीह के साथ एकता, आत्मा में जीवन, परमेश्वर का चुनाव, और रूपांतरित जीवन की नैतिकता।'),
  ('aaa00000-0000-0000-0000-000000000033', 'ml',
   'റോമർ: സുവിശേഷത്തിന്റെ ആഴം',
   'റോമർ ലേഖനം തിരുവെഴുത്തിലെ സുവിശേഷത്തിന്റെ ഏറ്റവും ക്രമബദ്ധമായ വ്യാഖ്യാനമാണ്. 16 അദ്ധ്യായങ്ങളിൽ: സാർവ്വത്രിക പാപം, വിശ്വാസത്താൽ നീതി, ക്രിസ്തുവുമായുള്ള ഐക്യം, ആത്മാവിൽ ജീവൻ, ദൈവ തിരഞ്ഞെടുപ്പ്, പരിവർത്തനം ചെയ്യപ്പെട്ട ജീവിതത്തിന്റെ ധർമ്മശാസ്ത്രം.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- Path 34: Crucifixion and Resurrection
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description) VALUES
  ('aaa00000-0000-0000-0000-000000000034', 'hi',
   'यीशु का क्रूस और पुनरुत्थान',
   'यह मसीही विश्वास का केंद्र है। अंतिम भोज से स्वर्गारोहण तक, 16 अध्ययनों में यीशु की गिरफ्तारी, परीक्षण, मृत्यु, दफनाने और शारीरिक पुनरुत्थान की कहानी का अनुसरण करें। यहाँ सुसमाचार अपने पूर्णतम रूप में है।'),
  ('aaa00000-0000-0000-0000-000000000034', 'ml',
   'യേശുവിന്റെ ക്രൂശുമരണവും പുനരുത്ഥാനവും',
   'ഇതാണ് ക്രിസ്തീയ വിശ്വാസത്തിന്റെ കേന്ദ്രം. അന്ത്യ അത്താഴം മുതൽ സ്വർഗ്ഗാരോഹണം വരെ, 16 പഠനങ്ങളിൽ യേശുവിന്റെ അറസ്റ്റ്, വിചാരണ, മരണം, സംസ്കാരം, ശാരീരിക പുനരുത്ഥാനം എന്നിവ പിന്തുടരുക. ഇവിടെ സുവിശേഷം അതിന്റെ പൂർണ്ണ രൂപത്തിൽ ഉണ്ട്.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- Ensure Romans category is Growth (handles both new insert and pre-existing rows)
UPDATE learning_paths SET category = 'Growth' WHERE id = 'aaa00000-0000-0000-0000-000000000033';


-- =====================================================
-- STEP 5: Recompute XP totals for the 4 new paths
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000031');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000032');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000033');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000034');


-- =====================================================
-- STEP 6: Verification queries
-- =====================================================

DO $$
DECLARE
  path_count INT;
  orphaned_count INT;
BEGIN
  -- Check all 4 new paths exist
  SELECT COUNT(*) INTO path_count
  FROM learning_paths
  WHERE id IN (
    'aaa00000-0000-0000-0000-000000000031',
    'aaa00000-0000-0000-0000-000000000032',
    'aaa00000-0000-0000-0000-000000000033',
    'aaa00000-0000-0000-0000-000000000034'
  );
  ASSERT path_count = 4, 'Expected 4 new learning paths, got: ' || path_count;

  -- Check no ab100000/ab200000/ab300000/ab400000 topics linked to wrong paths
  SELECT COUNT(*) INTO orphaned_count
  FROM learning_path_topics
  WHERE learning_path_id IN (
    'aaa00000-0000-0000-0000-000000000026',
    'aaa00000-0000-0000-0000-000000000027',
    'aaa00000-0000-0000-0000-000000000028',
    'aaa00000-0000-0000-0000-000000000029'
  ) AND (
    topic_id::text LIKE 'ab100000%' OR
    topic_id::text LIKE 'ab200000%' OR
    topic_id::text LIKE 'ab300000%' OR
    topic_id::text LIKE 'ab400000%'
  );
  ASSERT orphaned_count = 0, 'Expected 0 misplaced topics, found: ' || orphaned_count;

  RAISE NOTICE 'Fix migration verified successfully: 4 new paths created, 0 misplaced topics.';
END $$;

COMMIT;
