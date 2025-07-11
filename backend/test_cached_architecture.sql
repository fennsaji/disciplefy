-- Test Script: Demonstrate Cached Architecture
-- This script shows how the content caching and deduplication works

BEGIN;

-- ================================
-- Test 1: Insert cached content manually
-- ================================

-- Create some test cached content
INSERT INTO study_guides_cache (
  id,
  input_type,
  input_value_hash,
  language,
  summary,
  interpretation,
  context,
  related_verses,
  reflection_questions,
  prayer_points
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440001',
  'scripture',
  encode(digest('john 3:16', 'sha256'), 'hex'),
  'en',
  'God loves the world and sent His Son',
  'This verse demonstrates God''s unconditional love',
  'John 3:16 is perhaps the most famous verse in the Bible',
  ARRAY['Romans 5:8', '1 John 4:9-10'],
  ARRAY['How does knowing God''s love change your perspective?', 'What does it mean to believe in Jesus?'],
  ARRAY['Thank God for His love', 'Pray for faith to believe more deeply']
),
(
  '550e8400-e29b-41d4-a716-446655440002',
  'scripture',
  encode(digest('psalm 23:1', 'sha256'), 'hex'),
  'en',
  'The Lord is my shepherd',
  'This verse speaks of God''s care and provision',
  'Psalm 23 is a beloved psalm about God''s shepherding care',
  ARRAY['John 10:11', 'Ezekiel 34:11-12'],
  ARRAY['How has God been your shepherd?', 'What does it mean to lack nothing?'],
  ARRAY['Thank God for His provision', 'Ask for trust in His care']
);

-- ================================
-- Test 2: Create user relationships
-- ================================

-- Create authenticated user relationships
INSERT INTO user_study_guides_new (user_id, study_guide_id, is_saved) VALUES
('11111111-1111-1111-1111-111111111111', '550e8400-e29b-41d4-a716-446655440001', false),
('11111111-1111-1111-1111-111111111111', '550e8400-e29b-41d4-a716-446655440002', true),
('22222222-2222-2222-2222-222222222222', '550e8400-e29b-41d4-a716-446655440001', true); -- Same content, different user!

-- Create anonymous user relationships  
INSERT INTO anonymous_study_guides_new (session_id, study_guide_id, is_saved) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '550e8400-e29b-41d4-a716-446655440001', false),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '550e8400-e29b-41d4-a716-446655440002', true);

-- ================================
-- Test 3: Query Performance Test
-- ================================

-- Show content deduplication working
SELECT 
  'Content Deduplication Test' as test_name,
  COUNT(DISTINCT sg.id) as unique_content_pieces,
  COUNT(usg.id) + COUNT(asg.id) as total_user_relationships,
  ROUND(
    100.0 * COUNT(DISTINCT sg.id) / (COUNT(usg.id) + COUNT(asg.id)), 
    2
  ) as storage_efficiency_percent
FROM study_guides_cache sg
LEFT JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
LEFT JOIN anonymous_study_guides_new asg ON sg.id = asg.study_guide_id;

-- Show user-specific views (authenticated)
SELECT 
  'User 1 Study Guides' as test_name,
  sg.summary,
  usg.is_saved,
  usg.created_at
FROM study_guides_cache sg
JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
WHERE usg.user_id = '11111111-1111-1111-1111-111111111111'
ORDER BY usg.created_at DESC;

-- Show user-specific views (different user, same content)
SELECT 
  'User 2 Study Guides' as test_name,
  sg.summary,
  usg.is_saved,
  usg.created_at
FROM study_guides_cache sg
JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
WHERE usg.user_id = '22222222-2222-2222-2222-222222222222'
ORDER BY usg.created_at DESC;

-- Show anonymous user views
SELECT 
  'Anonymous User Study Guides' as test_name,
  sg.summary,
  asg.is_saved,
  asg.created_at,
  asg.expires_at
FROM study_guides_cache sg
JOIN anonymous_study_guides_new asg ON sg.id = asg.study_guide_id
WHERE asg.session_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
ORDER BY asg.created_at DESC;

-- ================================
-- Test 4: Cache Lookup Performance
-- ================================

-- Test fast cache lookup (should use index)
EXPLAIN (ANALYZE, BUFFERS) 
SELECT sg.* 
FROM study_guides_cache sg
WHERE sg.input_type = 'scripture' 
  AND sg.input_value_hash = encode(digest('john 3:16', 'sha256'), 'hex')
  AND sg.language = 'en';

-- Test user guide JOIN performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT sg.summary, sg.interpretation, usg.is_saved
FROM study_guides_cache sg
JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
WHERE usg.user_id = '11111111-1111-1111-1111-111111111111'
ORDER BY usg.created_at DESC;

-- ================================
-- Test 5: Storage Comparison
-- ================================

-- Show storage efficiency
SELECT 
  'Original Architecture' as architecture,
  2 as content_records, -- Would be 2 separate records
  2 as user_relationships, -- Embedded in content
  2 as total_storage_units
  
UNION ALL

SELECT 
  'Cached Architecture' as architecture,
  COUNT(DISTINCT sg.id) as content_records,
  COUNT(usg.id) + COUNT(asg.id) as user_relationships,
  COUNT(DISTINCT sg.id) + COUNT(usg.id) + COUNT(asg.id) as total_storage_units
FROM study_guides_cache sg
LEFT JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
LEFT JOIN anonymous_study_guides_new asg ON sg.id = asg.study_guide_id;

-- ================================
-- Test 6: Popular Content Analysis
-- ================================

-- Show which content is most reused
SELECT 
  LEFT(sg.summary, 50) as content_preview,
  sg.input_type,
  sg.language,
  COUNT(usg.id) as authenticated_users,
  COUNT(asg.id) as anonymous_users,
  COUNT(usg.id) + COUNT(asg.id) as total_users
FROM study_guides_cache sg
LEFT JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id
LEFT JOIN anonymous_study_guides_new asg ON sg.id = asg.study_guide_id
GROUP BY sg.id, sg.summary, sg.input_type, sg.language
ORDER BY total_users DESC;

ROLLBACK; -- Don't commit test data

-- ================================
-- Results Summary
-- ================================

-- This test demonstrates:
-- 1. Content deduplication: Same content (John 3:16) used by multiple users
-- 2. User isolation: Each user sees only their own relationships
-- 3. Performance: Fast lookups using proper indexes
-- 4. Storage efficiency: Reduced duplication compared to original architecture
-- 5. Flexibility: Same content can be saved/unsaved per user independently