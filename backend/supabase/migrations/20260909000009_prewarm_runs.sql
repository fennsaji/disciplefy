-- Tracks the batch a pre-warm run has in flight.
--
-- A standard study is two passes and the second reads the first, so a run is
-- two batches in sequence. Anthropic keeps batch results retrievable, so the
-- only thing worth persisting is which batch is outstanding and which pass it
-- belongs to: after a restart the job re-fetches the results and carries on.

CREATE TABLE IF NOT EXISTS public.prewarm_runs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id      TEXT        NOT NULL,
  -- Kept when pass 2 is submitted: a finished guide needs both halves, and
  -- pass 1's results stay retrievable from Anthropic by its batch id.
  pass1_batch_id TEXT,
  phase         TEXT        NOT NULL CHECK (phase IN ('pass1', 'pass2')),
  status        TEXT        NOT NULL DEFAULT 'submitted'
                            CHECK (status IN ('submitted', 'completed', 'failed')),
  request_count INT         NOT NULL DEFAULT 0,
  guides_written INT        NOT NULL DEFAULT 0,
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- At most one run in flight; the job submits nothing while one is outstanding.
CREATE UNIQUE INDEX IF NOT EXISTS idx_prewarm_runs_one_in_flight
    ON public.prewarm_runs ((status))
 WHERE status = 'submitted';

ALTER TABLE public.prewarm_runs ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.prewarm_runs TO service_role;

NOTIFY pgrst, 'reload schema';
