-- =====================================================
-- Migration: Fix Learning Paths Review Issues
-- =====================================================
-- Fixes verified issues from docs/planning/learning_paths_review_issues.md
-- Issues: H-3, H-4, H-6, M-5, M-8, M-10, M-11, M-12, L-4, L-5, L-6, L-10
-- =====================================================

BEGIN;

-- =====================================================
-- 1. DISPLAY ORDER FIXES (category ordering)
-- =====================================================

-- H-3: Service & Mission — beginner paths lead, leader path last
--   P17 The Local Church (beginner/follower) → 6
--   P18 Evangelism in Everyday Life (beginner/follower) → 7
--   P7  Heart for the World (intermediate/leader) → 20
UPDATE learning_paths SET display_order = 6
WHERE id = 'aaa00000-0000-0000-0000-000000000017';

UPDATE learning_paths SET display_order = 7
WHERE id = 'aaa00000-0000-0000-0000-000000000018';

UPDATE learning_paths SET display_order = 20
WHERE id = 'aaa00000-0000-0000-0000-000000000007';

-- H-4: Theology — beginner path leads
--   P28 Sin, Repentance & Grace (beginner/seeker) → 8
--   P31 Jesus's Parables (intermediate/follower) → 9
UPDATE learning_paths SET display_order = 8
WHERE id = 'aaa00000-0000-0000-0000-000000000028';

UPDATE learning_paths SET display_order = 9
WHERE id = 'aaa00000-0000-0000-0000-000000000031';

-- M-8: Growth — follower before disciple paths
--   P15 Money & Generosity (intermediate/follower) → 3
UPDATE learning_paths SET display_order = 3
WHERE id = 'aaa00000-0000-0000-0000-000000000015';

-- L-6: Life & Relationships — beginner before intermediate
--   P25 Friendship & Community (beginner) → 23 (before P24 at 24)
UPDATE learning_paths SET display_order = 23
WHERE id = 'aaa00000-0000-0000-0000-000000000025';


-- =====================================================
-- 2. MILESTONE FIXES
-- =====================================================

-- M-5: P10 (Faith & Reason) — move first milestone from pos 1 (7%) to pos 5 (36%)
--   pos 1 "Why Evil and Suffering?" loses milestone
--   pos 5 "The Resurrection as Historical Fact" gains milestone
UPDATE learning_path_topics SET is_milestone = false
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND position = 1;

UPDATE learning_path_topics SET is_milestone = true
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND position = 5;

-- L-4: P4 (Defending Your Faith) — remove consecutive milestone at pos 7
--   Keeps pos 8 "Faith and Science" as final milestone
UPDATE learning_path_topics SET is_milestone = false
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004' AND position = 7;

-- L-5: P5 (Faith & Family) — remove consecutive milestone at pos 5
--   Keeps pos 6 "Raising Children" as milestone (next after pos 2)
UPDATE learning_path_topics SET is_milestone = false
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005' AND position = 5;


-- =====================================================
-- 3. TOPIC REORDER: H-6 — P9 (Eternal Perspective)
-- =====================================================
-- Swap "Heaven and Eternal Life" (pos 1→3 finale) with
--      "Living by Faith, Not Feelings" (pos 3→1)
-- Use temp position to avoid unique constraint violation

UPDATE learning_path_topics SET position = 99
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009'
  AND topic_id = '999e8400-e29b-41d4-a716-446655440002';

UPDATE learning_path_topics SET position = 1, is_milestone = false
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009'
  AND topic_id = '444e8400-e29b-41d4-a716-446655440006';

UPDATE learning_path_topics SET position = 3, is_milestone = true
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009'
  AND topic_id = '999e8400-e29b-41d4-a716-446655440002';


-- =====================================================
-- 4. DESCRIPTION FIXES
-- =====================================================

-- M-10: P15 (Money & Generosity) — remove unverifiable claim
UPDATE learning_paths
SET description = 'Jesus frequently addressed money and possessions — because how we handle wealth reveals the state of our heart. Develop a biblical theology of money, contentment, stewardship, and radical generosity rooted in the gospel.'
WHERE id = 'aaa00000-0000-0000-0000-000000000015';

UPDATE learning_path_translations
SET description = 'यीशु ने बार-बार धन और संपत्ति के बारे में बात की — क्योंकि हम संपत्ति को कैसे संभालते हैं यह हमारे दिल की स्थिति को प्रकट करता है।'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000015' AND lang_code = 'hi';

UPDATE learning_path_translations
SET description = 'യേശു പണത്തെയും സ്വത്തുക്കളെയും കുറിച്ച് ഇടയ്ക്കിടെ സംസാരിച്ചു — കാരണം നാം സ്വത്ത് കൈകാര്യം ചെയ്യുന്ന രീതി നമ്മുടെ ഹൃദയത്തിന്റെ അവസ്ഥ വെളിപ്പെടുത്തുന്നു.'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000015' AND lang_code = 'ml';

-- M-10: Also fix the topic description for consistency
UPDATE recommended_topics
SET description = 'Jesus frequently addressed money and possessions — because how we handle wealth reveals the state of our heart. Survey the Bible''s comprehensive teaching on money: from Proverbs'' wisdom to Jesus'' warnings, from Paul''s contentment to the early church''s generosity. Money is a tool, not a master — learn to hold it accordingly.'
WHERE id = 'fff00000-e29b-41d4-a716-446655440001';

-- M-11: P24 (Mental Health) — add gospel anchor
UPDATE learning_paths
SET description = 'The gospel speaks to the whole person — body, mind, and soul. Learn what Scripture says about emotions, anxiety, depression, grief, and the journey toward wholeness — anchored in the finished work of Christ, who gives real hope in the midst of real pain. Find that God meets the struggling and brokenhearted with grace, not shame.'
WHERE id = 'aaa00000-0000-0000-0000-000000000024';

UPDATE learning_path_translations
SET description = 'सुसमाचार पूरे व्यक्ति से बोलता है — शरीर, मन और आत्मा। पवित्रशास्त्र भावनाओं, चिंता, अवसाद और पूर्णता की यात्रा के बारे में क्या कहता है सीखें — मसीह के सिद्ध कार्य में लंगर डाले, जो वास्तविक दर्द के बीच वास्तविक आशा देता है।'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000024' AND lang_code = 'hi';

UPDATE learning_path_translations
SET description = 'സുവിശേഷം മുഴുവൻ വ്യക്തിയോടും സംസാരിക്കുന്നു — ശരീരം, മനസ്സ്, ആത്മാവ്. വികാരങ്ങൾ, ഉത്കണ്ഠ, വിഷാദം, സൗഖ്യത്തിലേക്കുള്ള യാത്ര എന്നിവയെക്കുറിച്ച് വേദഗ്രന്ഥം പഠിക്കുക — യഥാർത്ഥ വേദനയിൽ യഥാർത്ഥ പ്രത്യാശ നൽകുന്ന ക്രിസ്തുവിന്റെ പൂർത്തിയാക്കിയ വേലയിൽ അടിയുറച്ചത്.'
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000024' AND lang_code = 'ml';


-- =====================================================
-- 5. DUPLICATE TOPIC FIX: M-12 — P22 (Christianity & Culture)
-- =====================================================
-- Remove "Responding to Common Questions" (same UUID as P4's copy)
-- Then shift remaining topic position down

DELETE FROM learning_path_topics
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000022'
  AND topic_id = '666e8400-e29b-41d4-a716-446655440004';

-- Shift "Speaking Truth in Love" from position 6 → 5
UPDATE learning_path_topics SET position = 5
WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000022'
  AND position = 6;


-- =====================================================
-- 6. TOPIC TITLE FIX: L-10 — P32 (Sermon on the Mount)
-- =====================================================
-- Rename "Nonresistance" to denominationally neutral title

UPDATE recommended_topics
SET title = 'Turning the Other Cheek: The Ethic of the Kingdom'
WHERE id = 'ab200000-e29b-41d4-a716-446655440008';

UPDATE recommended_topics_translations
SET title = 'दूसरा गाल आगे करना: राज्य की नैतिकता'
WHERE topic_id = 'ab200000-e29b-41d4-a716-446655440008' AND language_code = 'hi';

UPDATE recommended_topics_translations
SET title = 'മറ്റേ കവിൾ തിരിക്കുക: രാജ്യത്തിന്റെ നീതിശാസ്ത്രം'
WHERE topic_id = 'ab200000-e29b-41d4-a716-446655440008' AND language_code = 'ml';


-- =====================================================
-- 7. RECOMPUTE XP FOR AFFECTED PATHS
-- =====================================================

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000022');


-- =====================================================
-- 8. VERIFICATION
-- =====================================================

DO $$
DECLARE
  v_count INT;
  v_order INT;
BEGIN
  -- H-3: Service & Mission order: P17 (6) < P18 (7) < P7 (20)
  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000017';
  IF v_order != 6 THEN RAISE EXCEPTION 'VERIFY FAILED: P17 display_order = %, expected 6', v_order; END IF;

  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000018';
  IF v_order != 7 THEN RAISE EXCEPTION 'VERIFY FAILED: P18 display_order = %, expected 7', v_order; END IF;

  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000007';
  IF v_order != 20 THEN RAISE EXCEPTION 'VERIFY FAILED: P7 display_order = %, expected 20', v_order; END IF;

  -- H-4: Theology order: P28 (8) < P31 (9)
  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000028';
  IF v_order != 8 THEN RAISE EXCEPTION 'VERIFY FAILED: P28 display_order = %, expected 8', v_order; END IF;

  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000031';
  IF v_order != 9 THEN RAISE EXCEPTION 'VERIFY FAILED: P31 display_order = %, expected 9', v_order; END IF;

  -- M-8: Growth: P15 at 3
  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000015';
  IF v_order != 3 THEN RAISE EXCEPTION 'VERIFY FAILED: P15 display_order = %, expected 3', v_order; END IF;

  -- L-6: Life & Relationships: P25 at 23
  SELECT display_order INTO v_order FROM learning_paths WHERE id = 'aaa00000-0000-0000-0000-000000000025';
  IF v_order != 23 THEN RAISE EXCEPTION 'VERIFY FAILED: P25 display_order = %, expected 23', v_order; END IF;

  -- M-5: P10 milestone moved from pos 1 to pos 5
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND position = 1 AND is_milestone = true;
  IF v_count != 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P10 still has milestone at position 1'; END IF;

  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010' AND position = 5 AND is_milestone = true;
  IF v_count != 1 THEN RAISE EXCEPTION 'VERIFY FAILED: P10 missing milestone at position 5'; END IF;

  -- L-4: P4 no milestone at position 7
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000004' AND position = 7 AND is_milestone = true;
  IF v_count != 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P4 still has milestone at position 7'; END IF;

  -- L-5: P5 no milestone at position 5
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000005' AND position = 5 AND is_milestone = true;
  IF v_count != 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P5 still has milestone at position 5'; END IF;

  -- H-6: P9 "Heaven and Eternal Life" at position 3 (finale milestone)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009'
    AND topic_id = '999e8400-e29b-41d4-a716-446655440002'
    AND position = 3 AND is_milestone = true;
  IF v_count != 1 THEN RAISE EXCEPTION 'VERIFY FAILED: P9 Heaven not at position 3 with milestone'; END IF;

  -- H-6: P9 "Living by Faith" at position 1 (no milestone)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009'
    AND topic_id = '444e8400-e29b-41d4-a716-446655440006'
    AND position = 1 AND is_milestone = false;
  IF v_count != 1 THEN RAISE EXCEPTION 'VERIFY FAILED: P9 Living by Faith not at position 1'; END IF;

  -- M-12: P22 has 6 topics (was 7)
  SELECT COUNT(*) INTO v_count FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000022';
  IF v_count != 6 THEN RAISE EXCEPTION 'VERIFY FAILED: P22 has % topics, expected 6', v_count; END IF;

  -- M-12: P22 no duplicate positions
  SELECT COUNT(*) - COUNT(DISTINCT position) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000022';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P22 has duplicate positions'; END IF;

  -- L-10: Topic title updated
  SELECT COUNT(*) INTO v_count FROM recommended_topics
  WHERE id = 'ab200000-e29b-41d4-a716-446655440008'
    AND title = 'Turning the Other Cheek: The Ethic of the Kingdom';
  IF v_count != 1 THEN RAISE EXCEPTION 'VERIFY FAILED: P32 topic not renamed'; END IF;

  -- P9 no duplicate positions
  SELECT COUNT(*) - COUNT(DISTINCT position) INTO v_count
  FROM learning_path_topics WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000009';
  IF v_count > 0 THEN RAISE EXCEPTION 'VERIFY FAILED: P9 has duplicate positions'; END IF;

  RAISE NOTICE 'VERIFICATION PASSED: All review issue fixes applied successfully';
END $$;

COMMIT;
