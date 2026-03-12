-- Blog posts table for the Rust blog backend service
-- Stores both auto-generated (from learning path topics) and manually created posts

BEGIN;

CREATE TABLE IF NOT EXISTS blog_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  excerpt TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  author TEXT NOT NULL DEFAULT 'Disciplefy Team',
  locale TEXT NOT NULL CHECK (locale IN ('en', 'hi', 'ml')),
  tags TEXT[] NOT NULL DEFAULT '{}',
  featured BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),

  source_type TEXT CHECK (source_type IN ('learning_path_topic', 'manual')),
  source_topic_id UUID,
  source_learning_path_id UUID,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at TIMESTAMPTZ
);

-- Query indexes
CREATE INDEX idx_blog_posts_locale_status ON blog_posts(locale, status, published_at DESC);
CREATE INDEX idx_blog_posts_source ON blog_posts(source_topic_id, locale);
-- slug already has a UNIQUE constraint which creates an implicit index

-- Prevent duplicate auto-generated posts per topic+locale
CREATE UNIQUE INDEX idx_blog_posts_source_unique
  ON blog_posts(source_topic_id, locale)
  WHERE source_topic_id IS NOT NULL;

-- Full-text search index (use 'simple' config for multilingual support)
CREATE INDEX idx_blog_posts_fts ON blog_posts
  USING GIN (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(excerpt, '') || ' ' || coalesce(content, '')));

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_blog_posts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER blog_posts_updated_at
  BEFORE UPDATE ON blog_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_blog_posts_updated_at();

-- RLS: public read for published, service_role for write
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY blog_posts_public_read ON blog_posts
  FOR SELECT USING (status = 'published');

CREATE POLICY blog_posts_service_write ON blog_posts
  FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

COMMIT;
