-- =====================================================
-- Migration: Merge Overlapping Learning Paths
-- =====================================================
-- Consolidates 4 redundant learning paths into 3 surviving paths:
--   P3  (Serving & Mission)         → soft-delete (all topics in P17+P18+P19)
--   P21 (Responding to Cults)       → merge into P4  (Defending Your Faith)
--   P23 (Singleness/Dating/Marriage)→ merge into P5  (Faith & Family)
--   P29 (The Big Questions)         → merge into P10 (Faith & Reason)
-- =====================================================

BEGIN;

-- =====================================================
-- MERGE 1: Soft-delete Path 3 (Serving & Mission)
-- All 9 topics already exist in P17 + P18 + P19
-- =====================================================

UPDATE learning_paths
SET is_active = false, updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000003';


-- =====================================================
-- MERGE 2: Path 21 (Responding to Cults) → Path 4 (Defending Your Faith)
-- 3/6 topics shared (50% overlap). 3 new topics added to P4.
-- New P4: 9 topics, estimated_days = 28
-- =====================================================

-- Step 2a: Delete existing P4 topic assignments
DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004';

-- Step 2b: Re-insert P4 topics in new merged order (9 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440001', 0, false),  -- Why We Believe in One God
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440002', 1, false),  -- The Uniqueness of Jesus
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440003', 2, true),   -- Is the Bible Reliable? (Milestone)
  ('aaa00000-0000-0000-0000-000000000004', 'ab600000-e29b-41d4-a716-446655440001', 3, false),  -- What Makes a Teaching False? (NEW from P21)
  ('aaa00000-0000-0000-0000-000000000004', 'ab600000-e29b-41d4-a716-446655440002', 4, false),  -- Recognizing Cultic Patterns (NEW from P21)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440004', 5, false),  -- Responding to Common Questions
  ('aaa00000-0000-0000-0000-000000000004', 'ab600000-e29b-41d4-a716-446655440003', 6, true),   -- Grace vs. Works-Based Religion (NEW from P21, Milestone)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440005', 7, true),   -- Standing Firm (Milestone)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440006', 8, true);   -- Faith and Science (Milestone)

-- Step 2c: Update P4 metadata
UPDATE learning_paths SET
  estimated_days = 28,
  description = 'Build confidence in sharing and defending your beliefs. Learn to identify false teaching, recognize cultic patterns, and respond to tough questions with wisdom, grace, and biblical understanding.',
  updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000004';

-- Step 2d: Update P4 translations
UPDATE learning_path_translations SET
  description = 'अपने विश्वासों को साझा करने और उनकी रक्षा करने में आत्मविश्वास बनाएं। झूठी शिक्षाओं की पहचान करना, पंथ के पैटर्न को पहचानना, और बुद्धि, अनुग्रह और बाइबिल की समझ के साथ कठिन प्रश्नों का उत्तर देना सीखें।'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004' AND lang_code = 'hi';

UPDATE learning_path_translations SET
  description = 'നിങ്ങളുടെ വിശ്വാസങ്ങൾ പങ്കുവെക്കുന്നതിലും സംരക്ഷിക്കുന്നതിലും ആത്മവിശ്വാസം വളർത്തുക. തെറ്റായ ഉപദേശങ്ങൾ തിരിച്ചറിയാനും കൾട്ട് പാറ്റേണുകൾ തിരിച്ചറിയാനും ജ്ഞാനത്തോടെയും കൃപയോടെയും ബൈബിൾ ധാരണയോടെയും കഠിനമായ ചോദ്യങ്ങൾക്ക് ഉത്തരം നൽകാനും പഠിക്കുക.'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004' AND lang_code = 'ml';

-- Step 2e: Soft-delete P21
UPDATE learning_paths
SET is_active = false, updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000021';


-- =====================================================
-- MERGE 3: Path 23 (Singleness/Dating/Marriage) → Path 5 (Faith & Family)
-- 3/6 topics shared (50% overlap). 4 new topics added to P5.
-- New P5: 10 topics, estimated_days = 35
-- =====================================================

-- Step 3a: Delete existing P5 topic assignments
DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005';

-- Step 3b: Re-insert P5 topics in new merged order (10 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440006', 0, false),  -- Singleness and Contentment
  ('aaa00000-0000-0000-0000-000000000005', 'ab800000-e29b-41d4-a716-446655440001', 1, false),  -- God's Design for Marriage (NEW from P23)
  ('aaa00000-0000-0000-0000-000000000005', 'ab800000-e29b-41d4-a716-446655440002', 2, true),   -- Purity Before Marriage (NEW from P23, Milestone)
  ('aaa00000-0000-0000-0000-000000000005', 'ab800000-e29b-41d4-a716-446655440003', 3, false),  -- Choosing a Spouse Wisely (NEW from P23)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440001', 4, false),  -- Marriage and Faith
  ('aaa00000-0000-0000-0000-000000000005', 'ab800000-e29b-41d4-a716-446655440004', 5, true),   -- When Marriage Is Hard (NEW from P23, Milestone)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440002', 6, true),   -- Raising Children (Milestone)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440003', 7, false),  -- Honoring Parents
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440004', 8, false),  -- Healthy Friendships
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440005', 9, true);   -- Resolving Conflicts (Milestone)

-- Step 3c: Update P5 metadata
UPDATE learning_paths SET
  estimated_days = 35,
  description = 'Strengthen your relationships and build a Christ-centered home. From singleness and purity to marriage, parenting, and friendships — learn God''s design for every season of life.',
  updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000005';

-- Step 3d: Update P5 translations
UPDATE learning_path_translations SET
  title = 'विश्वास और परिवार',
  description = 'अपने रिश्तों को मजबूत करें और मसीह-केंद्रित घर बनाएं। अविवाहित जीवन और पवित्रता से लेकर विवाह, पालन-पोषण और मित्रता तक — जीवन के हर मौसम के लिए परमेश्वर की योजना जानें।'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005' AND lang_code = 'hi';

UPDATE learning_path_translations SET
  title = 'വിശ്വാസവും കുടുംബവും',
  description = 'നിങ്ങളുടെ ബന്ധങ്ങൾ ശക്തിപ്പെടുത്തുകയും ക്രിസ്തു കേന്ദ്രീകൃത ഭവനം കെട്ടിപ്പടുക്കുകയും ചെയ്യുക. ഒറ്റയ്ക്കുള്ള ജീവിതവും പരിശുദ്ധിയും മുതൽ വിവാഹം, മാതാപിതൃത്വം, സൗഹൃദം വരെ — ജീവിതത്തിന്റെ ഓരോ ഋതുവിനുമുള്ള ദൈവത്തിന്റെ രൂപകൽപ്പന പഠിക്കുക.'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005' AND lang_code = 'ml';

-- Step 3e: Soft-delete P23
UPDATE learning_paths
SET is_active = false, updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000023';


-- =====================================================
-- MERGE 4: Path 29 (The Big Questions) → Path 10 (Faith & Reason)
-- Thematic near-duplicate (beginner vs advanced). 2 new topics added.
-- New P10: 14 topics, estimated_days = 35
-- =====================================================

-- Step 4a: Delete existing P10 topic assignments
DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';

-- Step 4b: Re-insert P10 topics in new merged order (14 topics)
-- NOTE: "The Resurrection as Historical Fact" uses b0200000-...-004 (remapped in Hebrews collision fix)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone) VALUES
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440001',  0, false),  -- Does God Exist?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440002',  1, true),   -- Why Evil and Suffering? (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', 'abe00000-e29b-41d4-a716-446655440001',  2, false),  -- Did Jesus Actually Exist? (NEW from P29)
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440003',  3, false),  -- Jesus Only Way?
  ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440003',  4, false),  -- Is Bible Reliable?
  ('aaa00000-0000-0000-0000-000000000010', 'b0200000-e29b-41d4-a716-446655440004',  5, true),   -- The Resurrection as Historical Fact (NEW from P29, Milestone)
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440004',  6, false),  -- Those Who Never Hear?
  ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440006',  7, true),   -- Faith and Science (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440005',  8, false),  -- What is Trinity?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440006',  9, false),  -- Unanswered Prayers?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440007', 10, true),   -- Predestination vs Free Will (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', '999e8400-e29b-41d4-a716-446655440002', 11, false),  -- Heaven and Eternal Life
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440008', 12, false),  -- Many Denominations?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440009', 13, true);   -- Purpose in Life? (Milestone)

-- Step 4c: Update P10 metadata
UPDATE learning_paths SET
  estimated_days = 35,
  description = 'Explore Christianity''s toughest questions with biblical wisdom and historical evidence. From the existence of God and the historicity of Jesus to the problem of evil and the purpose of life — build confident, well-reasoned faith.',
  updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000010';

-- Step 4d: Update P10 translations
UPDATE learning_path_translations SET
  description = 'बाइबिल की बुद्धि और ऐतिहासिक साक्ष्य के साथ ईसाई धर्म के सबसे कठिन सवालों का पता लगाएं। परमेश्वर के अस्तित्व और यीशु की ऐतिहासिकता से लेकर बुराई की समस्या और जीवन के उद्देश्य तक — आत्मविश्वासी, तर्कसंगत विश्वास बनाएं।'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND lang_code = 'hi';

UPDATE learning_path_translations SET
  description = 'ബൈബിൾ ജ്ഞാനവും ചരിത്രപരമായ തെളിവുകളും ഉപയോഗിച്ച് ക്രിസ്തുമതത്തിന്റെ ഏറ്റവും കഠിനമായ ചോദ്യങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക. ദൈവത്തിന്റെ അസ്തിത്വവും യേശുവിന്റെ ചരിത്രപരതയും മുതൽ തിന്മയുടെ പ്രശ്നവും ജീവിതത്തിന്റെ ഉദ്ദേശ്യവും വരെ — ആത്മവിശ്വാസമുള്ള, ന്യായബദ്ധമായ വിശ്വാസം വളർത്തുക.'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND lang_code = 'ml';

-- Step 4e: Soft-delete P29
UPDATE learning_paths
SET is_active = false, updated_at = NOW()
WHERE id = 'aaa00000-0000-0000-0000-000000000029';


-- =====================================================
-- STEP 5: User enrollment migration
-- Auto-enroll users from source paths into target paths
-- ON CONFLICT DO NOTHING preserves existing enrollments
-- =====================================================

-- P21 users → P4
INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at)
SELECT user_id, 'aaa00000-0000-0000-0000-000000000004', NOW()
FROM user_learning_path_progress
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000021'
ON CONFLICT (user_id, learning_path_id) DO NOTHING;

-- P23 users → P5
INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at)
SELECT user_id, 'aaa00000-0000-0000-0000-000000000005', NOW()
FROM user_learning_path_progress
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000023'
ON CONFLICT (user_id, learning_path_id) DO NOTHING;

-- P29 users → P10
INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at)
SELECT user_id, 'aaa00000-0000-0000-0000-000000000010', NOW()
FROM user_learning_path_progress
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000029'
ON CONFLICT (user_id, learning_path_id) DO NOTHING;

-- P3 users → no specific target (topics spread across P17/P18/P19)
-- Users keep their P3 enrollment record but path is hidden from UI


-- =====================================================
-- STEP 6: Recompute total XP for modified paths
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000004');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000005');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000010');


-- =====================================================
-- STEP 7: Verification assertions
-- =====================================================

DO $$
DECLARE
  v_count INTEGER;
  v_active BOOLEAN;
BEGIN
  -- Verify P3 is deactivated
  SELECT is_active INTO v_active FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000003';
  IF v_active THEN RAISE EXCEPTION 'VERIFY FAILED: P3 still active'; END IF;

  -- Verify P21 is deactivated
  SELECT is_active INTO v_active FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000021';
  IF v_active THEN RAISE EXCEPTION 'VERIFY FAILED: P21 still active'; END IF;

  -- Verify P23 is deactivated
  SELECT is_active INTO v_active FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000023';
  IF v_active THEN RAISE EXCEPTION 'VERIFY FAILED: P23 still active'; END IF;

  -- Verify P29 is deactivated
  SELECT is_active INTO v_active FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000029';
  IF v_active THEN RAISE EXCEPTION 'VERIFY FAILED: P29 still active'; END IF;

  -- Verify P4 has exactly 9 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004';
  IF v_count != 9 THEN RAISE EXCEPTION 'VERIFY FAILED: P4 has % topics, expected 9', v_count; END IF;

  -- Verify P5 has exactly 10 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005';
  IF v_count != 10 THEN RAISE EXCEPTION 'VERIFY FAILED: P5 has % topics, expected 10', v_count; END IF;

  -- Verify P10 has exactly 14 topics
  SELECT COUNT(*) INTO v_count FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';
  IF v_count != 14 THEN RAISE EXCEPTION 'VERIFY FAILED: P10 has % topics, expected 14', v_count; END IF;

  -- Verify no duplicate positions in P4
  SELECT COUNT(*) - COUNT(DISTINCT position) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P4 has duplicate positions'; END IF;

  -- Verify no duplicate positions in P5
  SELECT COUNT(*) - COUNT(DISTINCT position) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P5 has duplicate positions'; END IF;

  -- Verify no duplicate positions in P10
  SELECT COUNT(*) - COUNT(DISTINCT position) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P10 has duplicate positions'; END IF;

  -- Verify no duplicate topic_ids in P4
  SELECT COUNT(*) - COUNT(DISTINCT topic_id) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P4 has duplicate topic_ids'; END IF;

  -- Verify no duplicate topic_ids in P5
  SELECT COUNT(*) - COUNT(DISTINCT topic_id) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P5 has duplicate topic_ids'; END IF;

  -- Verify no duplicate topic_ids in P10
  SELECT COUNT(*) - COUNT(DISTINCT topic_id) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P10 has duplicate topic_ids'; END IF;

  RAISE NOTICE 'VERIFICATION PASSED: All learning path merges applied successfully';
  RAISE NOTICE '  P3, P21, P23, P29 deactivated';
  RAISE NOTICE '  P4: 9 topics | P5: 10 topics | P10: 14 topics';
END $$;

COMMIT;
