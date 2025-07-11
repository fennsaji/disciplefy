-- Seed script for recommended topics
-- First, let's add some sample study guides to the cache table

BEGIN;

-- Insert sample study guides into cache table
INSERT INTO study_guides_cache (id, input_value, summary, content, created_at, updated_at)
VALUES
  (gen_random_uuid(), 'Understanding Biblical Context', 'Learn to read Scripture within its historical and cultural setting', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'The Scholar''s Approach to Scripture', 'Discovering what the text meant to its original audience', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Group Discussion Dynamics', 'Facilitating meaningful biblical conversations', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Personal Application of Scripture', 'Moving from understanding to life transformation', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'The Gospel in the Old Testament', 'Seeing Christ throughout the Hebrew Scriptures', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Prayer and Scripture Study', 'Integrating prayer into Bible study for spiritual insight', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Character Studies in Scripture', 'Learning from biblical characters and their journeys', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Understanding Biblical Covenants', 'Exploring God''s covenant relationship with humanity', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'The Parables of Jesus', 'Understanding the teaching method of Christ', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Spiritual Warfare and Victory', 'Biblical understanding of our battle and Christ''s victory', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Love and Relationships', 'Biblical foundations for healthy relationships', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Forgiveness and Grace', 'Understanding God''s forgiveness and extending it to others', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Faith and Doubt', 'Navigating seasons of doubt and growing in faith', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Worship and Praise', 'Biblical foundations for authentic worship', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW()),
  (gen_random_uuid(), 'Suffering and Hope', 'Finding hope and purpose in times of suffering', '{"context": "Sample context", "scholars_guide": "Sample scholars guide", "group_discussion": "Sample discussion", "application": "Sample application"}', NOW(), NOW());

-- Now link these study guides to recommended topics
INSERT INTO recommended_topics (study_guide_id, category, difficulty_level, estimated_duration, tags, display_order)
SELECT 
  sgc.id,
  CASE 
    WHEN sgc.input_value IN ('Understanding Biblical Context', 'The Scholar''s Approach to Scripture') THEN 'Bible Study Methods'
    WHEN sgc.input_value = 'Group Discussion Dynamics' THEN 'Group Leadership'
    WHEN sgc.input_value IN ('Personal Application of Scripture', 'Spiritual Warfare and Victory', 'Faith and Doubt') THEN 'Spiritual Growth'
    WHEN sgc.input_value IN ('The Gospel in the Old Testament', 'Understanding Biblical Covenants') THEN 'Biblical Theology'
    WHEN sgc.input_value IN ('Prayer and Scripture Study', 'Worship and Praise') THEN 'Spiritual Disciplines'
    WHEN sgc.input_value = 'Character Studies in Scripture' THEN 'Biblical Characters'
    WHEN sgc.input_value = 'The Parables of Jesus' THEN 'New Testament Studies'
    WHEN sgc.input_value IN ('Love and Relationships', 'Forgiveness and Grace') THEN 'Christian Living'
    WHEN sgc.input_value = 'Suffering and Hope' THEN 'Life Challenges'
    ELSE 'General'
  END as category,
  CASE 
    WHEN sgc.input_value IN ('Understanding Biblical Context', 'Personal Application of Scripture', 'Prayer and Scripture Study', 'Love and Relationships', 'Forgiveness and Grace', 'Worship and Praise') THEN 'beginner'
    WHEN sgc.input_value IN ('The Scholar''s Approach to Scripture', 'Group Discussion Dynamics', 'Character Studies in Scripture', 'The Parables of Jesus', 'Spiritual Warfare and Victory', 'Faith and Doubt') THEN 'intermediate'
    WHEN sgc.input_value IN ('The Gospel in the Old Testament', 'Understanding Biblical Covenants', 'Suffering and Hope') THEN 'advanced'
    ELSE 'beginner'
  END as difficulty_level,
  CASE 
    WHEN sgc.input_value = 'Prayer and Scripture Study' THEN '35 minutes'
    WHEN sgc.input_value = 'Personal Application of Scripture' THEN '40 minutes'
    WHEN sgc.input_value = 'Worship and Praise' THEN '40 minutes'
    WHEN sgc.input_value IN ('Understanding Biblical Context', 'Love and Relationships') THEN '45 minutes'
    WHEN sgc.input_value IN ('Group Discussion Dynamics', 'The Parables of Jesus', 'Forgiveness and Grace') THEN '50 minutes'
    WHEN sgc.input_value IN ('Character Studies in Scripture', 'Faith and Doubt') THEN '55 minutes'
    WHEN sgc.input_value IN ('The Scholar''s Approach to Scripture', 'Spiritual Warfare and Victory') THEN '60 minutes'
    WHEN sgc.input_value = 'Suffering and Hope' THEN '65 minutes'
    WHEN sgc.input_value = 'Understanding Biblical Covenants' THEN '70 minutes'
    WHEN sgc.input_value = 'The Gospel in the Old Testament' THEN '75 minutes'
    ELSE '45 minutes'
  END as estimated_duration,
  CASE 
    WHEN sgc.input_value = 'Understanding Biblical Context' THEN ARRAY['context', 'interpretation', 'hermeneutics']
    WHEN sgc.input_value = 'The Scholar''s Approach to Scripture' THEN ARRAY['scholarship', 'original meaning', 'exegesis']
    WHEN sgc.input_value = 'Group Discussion Dynamics' THEN ARRAY['discussion', 'community', 'facilitation']
    WHEN sgc.input_value = 'Personal Application of Scripture' THEN ARRAY['application', 'transformation', 'obedience']
    WHEN sgc.input_value = 'The Gospel in the Old Testament' THEN ARRAY['gospel', 'christology', 'old testament']
    WHEN sgc.input_value = 'Prayer and Scripture Study' THEN ARRAY['prayer', 'illumination', 'holy spirit']
    WHEN sgc.input_value = 'Character Studies in Scripture' THEN ARRAY['biography', 'character', 'examples']
    WHEN sgc.input_value = 'Understanding Biblical Covenants' THEN ARRAY['covenant', 'relationship', 'promise']
    WHEN sgc.input_value = 'The Parables of Jesus' THEN ARRAY['parables', 'teaching', 'kingdom']
    WHEN sgc.input_value = 'Spiritual Warfare and Victory' THEN ARRAY['warfare', 'victory', 'armor']
    WHEN sgc.input_value = 'Love and Relationships' THEN ARRAY['love', 'relationships', 'community']
    WHEN sgc.input_value = 'Forgiveness and Grace' THEN ARRAY['forgiveness', 'grace', 'reconciliation']
    WHEN sgc.input_value = 'Faith and Doubt' THEN ARRAY['faith', 'doubt', 'trust']
    WHEN sgc.input_value = 'Worship and Praise' THEN ARRAY['worship', 'praise', 'heart']
    WHEN sgc.input_value = 'Suffering and Hope' THEN ARRAY['suffering', 'hope', 'perseverance']
    ELSE ARRAY['general']
  END as tags,
  ROW_NUMBER() OVER (ORDER BY sgc.created_at) as display_order
FROM study_guides_cache sgc
WHERE sgc.input_value IN (
  'Understanding Biblical Context', 'The Scholar''s Approach to Scripture', 'Group Discussion Dynamics',
  'Personal Application of Scripture', 'The Gospel in the Old Testament', 'Prayer and Scripture Study',
  'Character Studies in Scripture', 'Understanding Biblical Covenants', 'The Parables of Jesus',
  'Spiritual Warfare and Victory', 'Love and Relationships', 'Forgiveness and Grace',
  'Faith and Doubt', 'Worship and Praise', 'Suffering and Hope'
);

COMMIT;