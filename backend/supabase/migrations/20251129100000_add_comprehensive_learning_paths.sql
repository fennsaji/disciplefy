-- Migration: Add Comprehensive Learning Paths
-- Purpose: Create additional learning paths to cover all 42 study topics
-- Date: 2025-11-29
--
-- This migration adds 4 new learning paths:
-- 1. Defending Your Faith (Apologetics) - 5 topics
-- 2. Faith & Family (Family & Relationships) - 5 topics
-- 3. Deepening Your Walk (Spiritual Disciplines + Christian Life) - 6 topics
-- 4. Heart for the World (Mission & Service + Discipleship) - 4 topics

BEGIN;

-- =============================================================================
-- LEARNING PATH 4: Defending Your Faith (Apologetics)
-- =============================================================================
-- A path for believers who want to strengthen their ability to share and defend their faith

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000004',
  'defending-your-faith',
  'Defending Your Faith',
  'Build confidence in sharing and defending your beliefs with wisdom, grace, and biblical understanding. Learn to respond to tough questions.',
  'shield',
  '#3B82F6',
  21,
  'intermediate',
  true,
  4
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Defending Your Faith (5 topics from Apologetics & Defense of Faith)
-- Topic IDs:
-- 666e8400-e29b-41d4-a716-446655440001 - Why We Believe in One God
-- 666e8400-e29b-41d4-a716-446655440002 - The Uniqueness of Jesus
-- 666e8400-e29b-41d4-a716-446655440003 - Is the Bible Reliable?
-- 666e8400-e29b-41d4-a716-446655440004 - Responding to Common Questions from Other Faiths
-- 666e8400-e29b-41d4-a716-446655440005 - Standing Firm in Persecution
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440001', 1, false),  -- Why We Believe in One God
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440002', 2, false),  -- The Uniqueness of Jesus
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440003', 3, true),   -- Is the Bible Reliable? (Milestone)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440004', 4, false),  -- Responding to Common Questions
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440005', 5, true)    -- Standing Firm in Persecution (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Defending Your Faith
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000004', 'hi', 'अपने विश्वास की रक्षा करना', 'ज्ञान, अनुग्रह और बाइबिल की समझ के साथ अपने विश्वासों को साझा करने और उनकी रक्षा करने में आत्मविश्वास बनाएं। कठिन प्रश्नों का उत्तर देना सीखें।'),
  ('aaa00000-0000-0000-0000-000000000004', 'ml', 'നിങ്ങളുടെ വിശ്വാസം സംരക്ഷിക്കുക', 'ജ്ഞാനത്തോടെയും കൃപയോടെയും ബൈബിൾ ധാരണയോടെയും നിങ്ങളുടെ വിശ്വാസങ്ങൾ പങ്കിടാനും സംരക്ഷിക്കാനും ആത്മവിശ്വാസം വളർത്തുക. കഠിനമായ ചോദ്യങ്ങൾക്ക് മറുപടി പറയാൻ പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- LEARNING PATH 5: Faith & Family (Family & Relationships)
-- =============================================================================
-- A path for building Christ-centered relationships and family life

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000005',
  'faith-and-family',
  'Faith & Family',
  'Strengthen your relationships and build a Christ-centered home through biblical principles. Learn God''s design for marriage, parenting, and friendships.',
  'family_restroom',
  '#EC4899',
  25,
  'beginner',
  true,
  5
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Faith & Family (5 topics from Family & Relationships)
-- Topic IDs:
-- 777e8400-e29b-41d4-a716-446655440001 - Marriage and Faith
-- 777e8400-e29b-41d4-a716-446655440002 - Raising Children in Christ
-- 777e8400-e29b-41d4-a716-446655440003 - Honoring Parents
-- 777e8400-e29b-41d4-a716-446655440004 - Healthy Friendships
-- 777e8400-e29b-41d4-a716-446655440005 - Resolving Conflicts Biblically
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440001', 1, false),  -- Marriage and Faith
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440002', 2, true),   -- Raising Children in Christ (Milestone)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440003', 3, false),  -- Honoring Parents
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440004', 4, false),  -- Healthy Friendships
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440005', 5, true)    -- Resolving Conflicts Biblically (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Faith & Family
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000005', 'hi', 'विश्वास और परिवार', 'बाइबिल के सिद्धांतों के माध्यम से अपने रिश्तों को मजबूत करें और मसीह-केंद्रित घर बनाएं। विवाह, पालन-पोषण और मित्रता के लिए परमेश्वर की योजना जानें।'),
  ('aaa00000-0000-0000-0000-000000000005', 'ml', 'വിശ്വാസവും കുടുംബവും', 'ബൈബിൾ തത്വങ്ങളിലൂടെ നിങ്ങളുടെ ബന്ധങ്ങൾ ശക്തിപ്പെടുത്തുകയും ക്രിസ്തു-കേന്ദ്രീകൃത ഭവനം കെട്ടിപ്പടുക്കുകയും ചെയ്യുക. വിവാഹം, കുട്ടികളെ വളർത്തൽ, സൗഹൃദം എന്നിവയ്ക്കുള്ള ദൈവത്തിന്റെ രൂപകൽപ്പന പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- LEARNING PATH 6: Deepening Your Walk (Spiritual Disciplines + Christian Life)
-- =============================================================================
-- A path for believers who want to go deeper in their relationship with God

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000006',
  'deepening-your-walk',
  'Deepening Your Walk',
  'Go deeper in your relationship with God through spiritual disciplines, fellowship, and generous living. Transform your daily habits into acts of worship.',
  'self_improvement',
  '#8B5CF6',
  28,
  'intermediate',
  false,
  6
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Deepening Your Walk (6 topics from Spiritual Disciplines + Christian Life + Church & Community)
-- Uncovered topics:
-- 555e8400-e29b-41d4-a716-446655440003 - Worship as a Lifestyle
-- 555e8400-e29b-41d4-a716-446655440005 - Journaling Your Walk with God
-- 222e8400-e29b-41d4-a716-446655440004 - The Importance of Fellowship
-- 222e8400-e29b-41d4-a716-446655440003 - Forgiveness and Reconciliation
-- 222e8400-e29b-41d4-a716-446655440005 - Giving and Generosity
-- 333e8400-e29b-41d4-a716-446655440004 - Unity in Christ
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000006', '555e8400-e29b-41d4-a716-446655440003', 1, false),  -- Worship as a Lifestyle
  ('aaa00000-0000-0000-0000-000000000006', '555e8400-e29b-41d4-a716-446655440005', 2, false),  -- Journaling Your Walk with God
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440004', 3, true),   -- The Importance of Fellowship (Milestone)
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440003', 4, false),  -- Forgiveness and Reconciliation
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440005', 5, false),  -- Giving and Generosity
  ('aaa00000-0000-0000-0000-000000000006', '333e8400-e29b-41d4-a716-446655440004', 6, true)    -- Unity in Christ (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Deepening Your Walk
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000006', 'hi', 'अपनी चाल को गहरा करना', 'आत्मिक अनुशासन, संगति और उदार जीवन के माध्यम से परमेश्वर के साथ अपने रिश्ते को गहरा करें। अपनी दैनिक आदतों को आराधना के कार्यों में बदलें।'),
  ('aaa00000-0000-0000-0000-000000000006', 'ml', 'നിങ്ങളുടെ നടത്തം ആഴപ്പെടുത്തുക', 'ആത്മീയ അനുശാസനങ്ങൾ, കൂട്ടായ്മ, ഔദാര്യമുള്ള ജീവിതം എന്നിവയിലൂടെ ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധം ആഴപ്പെടുത്തുക. നിങ്ങളുടെ ദൈനംദിന ശീലങ്ങളെ ആരാധന പ്രവൃത്തികളാക്കി മാറ്റുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- LEARNING PATH 7: Heart for the World (Mission & Service + Discipleship)
-- =============================================================================
-- A path for believers with a heart for global missions and local impact

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000007',
  'heart-for-the-world',
  'Heart for the World',
  'Develop a global perspective on missions and learn to impact your community and the nations for Christ. Become a multiplying disciple.',
  'public',
  '#F59E0B',
  21,
  'intermediate',
  false,
  7
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Heart for the World (4 topics from Mission & Service + Discipleship)
-- Uncovered topics:
-- 888e8400-e29b-41d4-a716-446655440003 - Serving the Poor and Needy
-- 888e8400-e29b-41d4-a716-446655440005 - Praying for the Nations
-- 444e8400-e29b-41d4-a716-446655440005 - Mentoring Others
-- Note: 444e8400-e29b-41d4-a716-446655440004 - The Great Commission is in Path 3
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000007', '888e8400-e29b-41d4-a716-446655440003', 1, false),  -- Serving the Poor and Needy
  ('aaa00000-0000-0000-0000-000000000007', '888e8400-e29b-41d4-a716-446655440005', 2, true),   -- Praying for the Nations (Milestone)
  ('aaa00000-0000-0000-0000-000000000007', '444e8400-e29b-41d4-a716-446655440005', 3, false),  -- Mentoring Others
  ('aaa00000-0000-0000-0000-000000000007', '444e8400-e29b-41d4-a716-446655440004', 4, true)    -- The Great Commission (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Heart for the World
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000007', 'hi', 'दुनिया के लिए दिल', 'मिशन पर एक वैश्विक दृष्टिकोण विकसित करें और मसीह के लिए अपने समुदाय और राष्ट्रों को प्रभावित करना सीखें। एक गुणा करने वाला शिष्य बनें।'),
  ('aaa00000-0000-0000-0000-000000000007', 'ml', 'ലോകത്തിനായുള്ള ഹൃദയം', 'മിഷനുകളെക്കുറിച്ച് ആഗോള വീക്ഷണം വികസിപ്പിക്കുകയും ക്രിസ്തുവിനായി നിങ്ങളുടെ സമൂഹത്തെയും രാഷ്ട്രങ്ങളെയും സ്വാധീനിക്കാൻ പഠിക്കുകയും ചെയ്യുക. ഒരു ഗുണിക്കുന്ന ശിഷ്യനാകുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =============================================================================
-- UPDATE TOTAL XP FOR ALL NEW PATHS
-- =============================================================================
-- Compute and update total_xp for each new learning path

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000004');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000005');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000006');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000007');


-- =============================================================================
-- VERIFICATION: Show topic coverage
-- =============================================================================
DO $$
DECLARE
  total_topics INT;
  covered_topics INT;
  uncovered_count INT;
BEGIN
  SELECT COUNT(*) INTO total_topics FROM recommended_topics WHERE is_active = true;
  SELECT COUNT(DISTINCT topic_id) INTO covered_topics FROM learning_path_topics;
  uncovered_count := total_topics - covered_topics;

  RAISE NOTICE '';
  RAISE NOTICE '=== Learning Paths Migration Summary ===';
  RAISE NOTICE 'Total active topics: %', total_topics;
  RAISE NOTICE 'Topics covered by paths: %', covered_topics;
  RAISE NOTICE 'Uncovered topics: %', uncovered_count;
  RAISE NOTICE '';

  IF uncovered_count > 0 THEN
    RAISE NOTICE 'WARNING: Some topics are not covered by any learning path!';
  ELSE
    RAISE NOTICE 'SUCCESS: All topics are covered by at least one learning path!';
  END IF;
END $$;

COMMIT;
