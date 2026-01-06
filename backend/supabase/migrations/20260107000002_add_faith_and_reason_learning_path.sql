-- ============================================================================
-- Migration: Add Faith & Reason Learning Path
-- Date: 2026-01-07
-- Description: Creates the "Faith & Reason" learning path (#10) addressing
--              popular theological and philosophical questions about Christianity.
--              Includes 12 topics (9 new + 3 existing) with Deep mode focus.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. INSERT LEARNING PATH
-- ============================================================================

INSERT INTO learning_paths (
  id,
  slug,
  title,
  description,
  icon_name,
  color,
  disciple_level,
  estimated_days,
  recommended_mode,
  is_featured,
  is_active,
  display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000010',
  'faith-and-reason',
  'Faith & Reason',
  'Explore Christianity''s toughest questions with biblical wisdom and theological depth. Build confidence in your faith through understanding God''s answers to life''s biggest questions.',
  'psychology',
  '#F59E0B',
  'disciple',
  28,
  'deep',
  true,
  true,
  10
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. INSERT TOPIC MAPPINGS (12 topics: 9 new + 3 existing)
-- ============================================================================

-- Position 1: Does God Exist? (NEW - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440001', 1, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 2: Why Does God Allow Evil and Suffering? (NEW - Deep - MILESTONE)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440002', 2, true)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 3: Is Jesus the Only Way to Salvation? (NEW - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440003', 3, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 4: Is the Bible Reliable? (EXISTING - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440003', 4, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 5: What About Those Who Never Hear the Gospel? (NEW - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440004', 5, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 6: Faith and Science (EXISTING - Deep - MILESTONE)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440006', 6, true)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 7: What is the Trinity? (NEW - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440005', 7, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 8: Why Doesn't God Answer My Prayers? (NEW - Standard)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440006', 8, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 9: Predestination vs. Free Will (NEW - Deep - MILESTONE)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440007', 9, true)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 10: Heaven and Eternal Life (EXISTING - Deep)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', '999e8400-e29b-41d4-a716-446655440002', 10, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 11: Why Are There So Many Christian Denominations? (NEW - Standard)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440008', 11, false)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Position 12: What is My Purpose in Life? (NEW - Standard - MILESTONE)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440009', 12, true)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- ============================================================================
-- 3. INSERT MULTILINGUAL TRANSLATIONS
-- ============================================================================

-- Hindi Translation
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES (
  'aaa00000-0000-0000-0000-000000000010',
  'hi',
  'विश्वास और तर्क',
  'बाइबिल की बुद्धि और धर्मशास्त्रीय गहराई के साथ ईसाई धर्म के सबसे कठिन सवालों का पता लगाएं। जीवन के सबसे बड़े सवालों के परमेश्वर के उत्तरों को समझकर अपने विश्वास में आत्मविश्वास बनाएं।'
)
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- Malayalam Translation
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES (
  'aaa00000-0000-0000-0000-000000000010',
  'ml',
  'വിശ്വാസവും യുക്തിയും',
  'ബൈബിൾ ജ്ഞാനവും ദൈവശാസ്ത്രപരമായ ആഴവും ഉപയോഗിച്ച് ക്രിസ്തുമതത്തിന്റെ ഏറ്റവും പ്രയാസകരമായ ചോദ്യങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക. ജീവിതത്തിലെ ഏറ്റവും വലിയ ചോദ്യങ്ങൾക്കുള്ള ദൈവത്തിന്റെ ഉത്തരങ്ങൾ മനസ്സിലാക്കി നിങ്ങളുടെ വിശ്വാസത്തിൽ ആത്മവിശ്വാസം വളർത്തുക.'
)
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;

-- ============================================================================
-- 4. COMPUTE TOTAL XP
-- ============================================================================

-- Calculate total XP from all 12 topics in this learning path
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000010');

-- ============================================================================
-- 5. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  path_exists BOOLEAN;
  topic_mapping_count INTEGER;
  milestone_count INTEGER;
  translation_count INTEGER;
  calculated_xp INTEGER;
BEGIN
  -- Check learning path was created
  SELECT EXISTS (
    SELECT 1 FROM learning_paths
    WHERE id = 'aaa00000-0000-0000-0000-000000000010'
      AND slug = 'faith-and-reason'
      AND recommended_mode = 'deep'
      AND disciple_level = 'disciple'
      AND is_featured = true
  ) INTO path_exists;

  IF NOT path_exists THEN
    RAISE EXCEPTION 'Learning path "Faith & Reason" was not created';
  END IF;

  -- Check all 12 topics are mapped
  SELECT COUNT(*) INTO topic_mapping_count
  FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';

  IF topic_mapping_count != 12 THEN
    RAISE EXCEPTION 'Expected 12 topic mappings, found %', topic_mapping_count;
  END IF;

  -- Check 4 milestones are set (positions 2, 6, 9, 12)
  SELECT COUNT(*) INTO milestone_count
  FROM learning_path_topics
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010'
    AND is_milestone = true;

  IF milestone_count != 4 THEN
    RAISE EXCEPTION 'Expected 4 milestones, found %', milestone_count;
  END IF;

  -- Check both translations exist (Hindi + Malayalam)
  SELECT COUNT(*) INTO translation_count
  FROM learning_path_translations
  WHERE learning_path_id = 'aaa00000-0000-0000-0000-000000000010';

  IF translation_count != 2 THEN
    RAISE EXCEPTION 'Expected 2 translations (Hindi + Malayalam), found %', translation_count;
  END IF;

  -- Check total XP was calculated (should be 12 topics × 50 XP = 600)
  SELECT total_xp INTO calculated_xp
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000010';

  IF calculated_xp IS NULL OR calculated_xp = 0 THEN
    RAISE EXCEPTION 'Total XP was not calculated (found %)', calculated_xp;
  END IF;

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Learning path "Faith & Reason" created';
  RAISE NOTICE '  - 12 topics mapped with proper positions';
  RAISE NOTICE '  - 4 milestones set (positions 2, 6, 9, 12)';
  RAISE NOTICE '  - 2 translations added (Hindi + Malayalam)';
  RAISE NOTICE '  - Total XP calculated: % XP', calculated_xp;
  RAISE NOTICE '  - Recommended mode: deep (75%% of topics)';
  RAISE NOTICE '  - Disciple level: disciple';
  RAISE NOTICE '  - Featured: true';
END $$;

COMMIT;
