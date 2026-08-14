-- Affiliate keywords: admin-curated terms auto-linked to Amazon affiliate
-- search URLs in marketing blog posts. Admin mutations go through the
-- admin-* Edge Functions (service role, bypasses RLS); the marketing site
-- reads active rows anonymously.
CREATE TABLE public.affiliate_keywords (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword     text NOT NULL,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX affiliate_keywords_keyword_unique
  ON public.affiliate_keywords (lower(keyword));

ALTER TABLE public.affiliate_keywords ENABLE ROW LEVEL SECURITY;

CREATE POLICY "affiliate_keywords_anon_read_active"
  ON public.affiliate_keywords FOR SELECT TO anon
  USING (is_active = true);

CREATE POLICY "affiliate_keywords_auth_read_active"
  ON public.affiliate_keywords FOR SELECT TO authenticated
  USING (is_active = true);

GRANT SELECT ON public.affiliate_keywords TO anon, authenticated;
GRANT ALL ON public.affiliate_keywords TO service_role;

-- Seed starter list (inactive — an admin flips them on once the Amazon
-- Associates tag is confirmed approved/working).
INSERT INTO public.affiliate_keywords (keyword, is_active) VALUES
  ('ESV Study Bible', false),
  ('NIV Study Bible', false),
  ('study Bible', false),
  ('Bible commentary', false),
  ('Strong''s Concordance', false),
  ('prayer journal', false),
  ('Christian devotional', false);
