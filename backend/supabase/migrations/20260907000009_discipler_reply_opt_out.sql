-- A mentor can silence Discipler on one question post without changing the
-- fellowship's reply settings. Default false, so every existing post and every
-- post created without the flag keeps today's behaviour.
ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS discipler_reply_opt_out BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN fellowship_posts.discipler_reply_opt_out IS
  'Author asked Discipler not to answer this post. Suppresses the question trigger only; an explicit @Discipler mention still replies.';
