-- A daily record of our own cost figures against Anthropic's.
--
-- Every cost number in the app is our arithmetic: token counts times a price
-- table kept by hand. That table has already been wrong three ways at once, and
-- nothing noticed, because the same wrong number fed the budgets, the ceiling
-- and the dashboard. Anthropic's Cost API reports what was actually billed;
-- storing both side by side makes a drift visible instead of silent.

CREATE TABLE IF NOT EXISTS public.cost_reconciliation (
  day           DATE PRIMARY KEY,
  our_usd       NUMERIC(12, 6) NOT NULL DEFAULT 0,
  anthropic_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
  gap_usd       NUMERIC(12, 6) NOT NULL DEFAULT 0,
  -- Against Anthropic's figure, since theirs is the one that is true.
  gap_percent   NUMERIC(8, 3)  NOT NULL DEFAULT 0,
  -- False when the admin key or workspace id is missing: the row then records
  -- only our own side, so a gap of zero is not mistaken for agreement.
  configured    BOOLEAN        NOT NULL DEFAULT FALSE,
  note          TEXT,
  checked_at    TIMESTAMPTZ    NOT NULL DEFAULT now()
);

ALTER TABLE public.cost_reconciliation ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.cost_reconciliation TO service_role;

NOTIFY pgrst, 'reload schema';
