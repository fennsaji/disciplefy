-- Seed Learning Paths with topic mappings and translations
-- Part of Phase 3: Study Topics Page Revamp
-- Creates 3 initial learning paths with Hindi and Malayalam translations

BEGIN;

-- =============================================================================
-- LEARNING PATH 1: New Believer Essentials (Beginner)
-- =============================================================================
-- A foundational journey for those new to faith

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000001',
  'new-believer-essentials',
  'New Believer Essentials',
  'Begin your faith journey with these foundational topics. Learn about Jesus, the Gospel, and how to grow in your relationship with God.',
  'auto_stories',
  '#4CAF50',
  14,
  'beginner',
  true,
  1
)
ON CONFLICT (id) DO NOTHING;

-- Topics for New Believer Essentials (6 topics from Foundations of Faith)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440001', 1, false),  -- Who is Jesus Christ?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440002', 2, false),  -- What is the Gospel?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440003', 3, true),   -- Assurance of Salvation (Milestone)
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440004', 4, false),  -- Why Read the Bible?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440005', 5, false),  -- Importance of Prayer
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440006', 6, true)    -- The Role of the Holy Spirit (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for New Believer Essentials
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000001', 'hi', 'नए विश्वासी की अनिवार्यताएं', 'इन मूलभूत विषयों के साथ अपनी विश्वास यात्रा शुरू करें। यीशु, सुसमाचार और परमेश्वर के साथ अपने रिश्ते में कैसे बढ़ें, इसके बारे में जानें।'),
  ('aaa00000-0000-0000-0000-000000000001', 'ml', 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനകാര്യങ്ങൾ', 'ഈ അടിസ്ഥാന വിഷയങ്ങളിലൂടെ നിങ്ങളുടെ വിശ്വാസ യാത്ര ആരംഭിക്കുക. യേശുവിനെയും സുവിശേഷത്തെയും ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധത്തിൽ എങ്ങനെ വളരാമെന്നും പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- LEARNING PATH 2: Growing in Discipleship (Intermediate)
-- =============================================================================
-- A path for believers ready to deepen their walk with God

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000002',
  'growing-in-discipleship',
  'Growing in Discipleship',
  'Deepen your faith and learn what it means to be a true disciple of Jesus. Explore spiritual disciplines, Christian living, and personal growth.',
  'trending_up',
  '#6A4FB6',
  21,
  'intermediate',
  true,
  2
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Growing in Discipleship (Mix from Christian Life, Discipleship & Growth, Spiritual Disciplines)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440001', 1, false),  -- What is Discipleship?
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440001', 2, false),  -- Walking with God Daily
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440001', 3, true),   -- Daily Devotions (Milestone)
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440002', 4, false),  -- The Cost of Following Jesus
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440002', 5, false),  -- Overcoming Temptation
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440002', 6, false),  -- Fasting and Prayer
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440003', 7, true),   -- Bearing Fruit (Milestone)
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440004', 8, false),  -- Meditation on God's Word
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440006', 9, true)    -- Living a Holy Life (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Growing in Discipleship
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000002', 'hi', 'शिष्यत्व में बढ़ना', 'अपने विश्वास को गहरा करें और जानें कि यीशु का सच्चा शिष्य होने का क्या अर्थ है। आत्मिक अनुशासन, मसीही जीवन और व्यक्तिगत विकास का अध्ययन करें।'),
  ('aaa00000-0000-0000-0000-000000000002', 'ml', 'ശിഷ്യത്വത്തിൽ വളർച്ച', 'നിങ്ങളുടെ വിശ്വാസം ആഴപ്പെടുത്തുകയും യേശുവിന്റെ യഥാർത്ഥ ശിഷ്യനാകുന്നതിന്റെ അർത്ഥം മനസ്സിലാക്കുകയും ചെയ്യുക. ആത്മീയ അനുശാസനങ്ങൾ, ക്രൈസ്തവ ജീവിതം, വ്യക്തിഗത വളർച്ച എന്നിവ പര്യവേക്ഷണം ചെയ്യുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- LEARNING PATH 3: Serving & Mission (Intermediate-Advanced)
-- =============================================================================
-- A path for believers ready to serve and share their faith

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000003',
  'serving-and-mission',
  'Serving & Mission',
  'Discover your calling to serve others and share the Gospel. Learn about church community, spiritual gifts, and reaching the world for Christ.',
  'volunteer_activism',
  '#FF7043',
  18,
  'intermediate',
  false,
  3
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Serving & Mission (Mix from Church & Community, Mission & Service, Discipleship)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440001', 1, false),  -- What is the Church?
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440002', 2, false),  -- Why Fellowship Matters
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440005', 3, true),   -- Spiritual Gifts and Their Use (Milestone)
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440003', 4, false),  -- Serving in the Church
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440001', 5, false),  -- Being the Light in Your Community
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440002', 6, true),   -- Sharing Your Testimony (Milestone)
  ('aaa00000-0000-0000-0000-000000000003', '444e8400-e29b-41d4-a716-446655440004', 7, false),  -- The Great Commission
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440004', 8, true)    -- Evangelism Made Simple (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Serving & Mission
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000003', 'hi', 'सेवा और मिशन', 'दूसरों की सेवा करने और सुसमाचार साझा करने की अपनी बुलाहट खोजें। कलीसिया समुदाय, आत्मिक वरदान और मसीह के लिए दुनिया तक पहुंचने के बारे में जानें।'),
  ('aaa00000-0000-0000-0000-000000000003', 'ml', 'സേവനവും മിഷനും', 'മറ്റുള്ളവരെ സേവിക്കാനും സുവിശേഷം പങ്കുവെക്കാനുമുള്ള നിങ്ങളുടെ വിളി കണ്ടെത്തുക. സഭാ സമൂഹം, ആത്മീയ വരദാനങ്ങൾ, ക്രിസ്തുവിനായി ലോകത്തെ എത്തിച്ചേരൽ എന്നിവയെക്കുറിച്ച് പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- UPDATE TOTAL XP FOR ALL PATHS
-- =============================================================================
-- Compute and update total_xp for each learning path

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000001');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000002');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000003');

COMMIT;
