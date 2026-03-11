-- Add topic_id to fellowship_posts for guide-specific discussions.
-- When a post is created from the guide detail screen, topic_id is set to
-- the LearningPathTopic.topicId so the feed can be filtered per guide.

ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS topic_id TEXT;

COMMENT ON COLUMN fellowship_posts.topic_id IS
  'Optional learning-path topic ID; used to scope posts to a specific guide discussion.';

-- Index for efficient per-guide feed queries
CREATE INDEX IF NOT EXISTS idx_fellowship_posts_topic
  ON fellowship_posts(fellowship_id, topic_id, created_at DESC)
  WHERE is_deleted = false AND topic_id IS NOT NULL;
