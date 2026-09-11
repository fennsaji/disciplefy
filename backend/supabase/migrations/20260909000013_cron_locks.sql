-- A lease each scheduled job holds while it runs.
--
-- The existing guard is an AtomicBool, which is per process. It stops a job
-- overlapping itself in one container and does nothing at all about a second
-- container, so the moment rs-backend runs more than one instance every job
-- fires twice: two daily posts in a fellowship, two Telegram messages, two
-- pre-warm batches billed twice.
--
-- A lease rather than an advisory lock: a session-level advisory lock is
-- released when its connection closes, but a pooled connection is returned
-- rather than closed, so a crashed job would hold the lock indefinitely. A
-- lease expires on its own, which is the behaviour worth having when the thing
-- holding it has died.

CREATE TABLE IF NOT EXISTS public.cron_locks (
  name         TEXT PRIMARY KEY,
  locked_until TIMESTAMPTZ NOT NULL,
  -- Which instance holds it, so a release cannot steal another's lease and the
  -- logs say who was running when something went wrong.
  holder       TEXT        NOT NULL,
  acquired_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.cron_locks ENABLE ROW LEVEL SECURITY;

GRANT ALL ON public.cron_locks TO service_role;

NOTIFY pgrst, 'reload schema';
