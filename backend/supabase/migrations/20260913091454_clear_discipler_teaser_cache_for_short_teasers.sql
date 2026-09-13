-- Daily teasers are now one short hook and one short sentence (see
-- buildDailyTeaserSystemPrompt). Cached wordings were written to the old,
-- longer brief, and some Malayalam ones were cut off mid-word by the old
-- 220-token limit, so clear them: each lesson regenerates once, in the new
-- shape, the next time a fellowship post or the Telegram channel uses it.
DELETE FROM public.discipler_teaser_cache;
