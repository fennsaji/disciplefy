-- Seed script for recommended topics
-- Add recommended topics directly (without needing study_guides_cache)

BEGIN;

-- Insert recommended topics with title and description
INSERT INTO recommended_topics (id, title, description, category, difficulty_level, estimated_duration, tags, display_order)
VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Understanding Biblical Context', 'Learn to read Scripture within its historical and cultural setting', 'Bible Study Methods', 'beginner', '45 minutes', ARRAY['context', 'interpretation', 'hermeneutics'], 1),
  ('550e8400-e29b-41d4-a716-446655440002', 'The Scholar''s Approach to Scripture', 'Discovering what the text meant to its original audience', 'Bible Study Methods', 'intermediate', '60 minutes', ARRAY['scholarship', 'original meaning', 'exegesis'], 2),
  ('550e8400-e29b-41d4-a716-446655440003', 'Group Discussion Dynamics', 'Facilitating meaningful biblical conversations', 'Group Leadership', 'intermediate', '50 minutes', ARRAY['discussion', 'community', 'facilitation'], 3),
  ('550e8400-e29b-41d4-a716-446655440004', 'Personal Application of Scripture', 'Moving from understanding to life transformation', 'Spiritual Growth', 'beginner', '40 minutes', ARRAY['application', 'transformation', 'obedience'], 4),
  ('550e8400-e29b-41d4-a716-446655440005', 'The Gospel in the Old Testament', 'Seeing Christ throughout the Hebrew Scriptures', 'Biblical Theology', 'advanced', '75 minutes', ARRAY['gospel', 'christology', 'old testament'], 5),
  ('550e8400-e29b-41d4-a716-446655440006', 'Prayer and Scripture Study', 'Integrating prayer into Bible study for spiritual insight', 'Spiritual Disciplines', 'beginner', '35 minutes', ARRAY['prayer', 'illumination', 'holy spirit'], 6),
  ('550e8400-e29b-41d4-a716-446655440007', 'Character Studies in Scripture', 'Learning from biblical characters and their journeys', 'Biblical Characters', 'intermediate', '55 minutes', ARRAY['biography', 'character', 'examples'], 7),
  ('550e8400-e29b-41d4-a716-446655440008', 'Understanding Biblical Covenants', 'Exploring God''s covenant relationship with humanity', 'Biblical Theology', 'advanced', '70 minutes', ARRAY['covenant', 'relationship', 'promise'], 8),
  ('550e8400-e29b-41d4-a716-446655440009', 'The Parables of Jesus', 'Understanding the teaching method of Christ', 'New Testament Studies', 'intermediate', '50 minutes', ARRAY['parables', 'teaching', 'kingdom'], 9),
  ('550e8400-e29b-41d4-a716-446655440010', 'Spiritual Warfare and Victory', 'Biblical understanding of our battle and Christ''s victory', 'Spiritual Growth', 'intermediate', '60 minutes', ARRAY['warfare', 'victory', 'armor'], 10),
  ('550e8400-e29b-41d4-a716-446655440011', 'Love and Relationships', 'Biblical foundations for healthy relationships', 'Christian Living', 'beginner', '45 minutes', ARRAY['love', 'relationships', 'community'], 11),
  ('550e8400-e29b-41d4-a716-446655440012', 'Forgiveness and Grace', 'Understanding God''s forgiveness and extending it to others', 'Christian Living', 'beginner', '50 minutes', ARRAY['forgiveness', 'grace', 'reconciliation'], 12),
  ('550e8400-e29b-41d4-a716-446655440013', 'Faith and Doubt', 'Navigating seasons of doubt and growing in faith', 'Spiritual Growth', 'intermediate', '55 minutes', ARRAY['faith', 'doubt', 'trust'], 13),
  ('550e8400-e29b-41d4-a716-446655440014', 'Worship and Praise', 'Biblical foundations for authentic worship', 'Spiritual Disciplines', 'beginner', '40 minutes', ARRAY['worship', 'praise', 'heart'], 14),
  ('550e8400-e29b-41d4-a716-446655440015', 'Suffering and Hope', 'Finding hope and purpose in times of suffering', 'Life Challenges', 'advanced', '65 minutes', ARRAY['suffering', 'hope', 'perseverance'], 15);

COMMIT;