-- Ensure every learning path uses 'standard' as its recommended study mode.
-- A prior blanket update (20260328000001) set all existing rows to 'standard',
-- but learning paths seeded afterwards (e.g. epistle/gospel) may carry other
-- modes. This idempotent update only touches rows not already 'standard'.
UPDATE learning_paths
SET recommended_mode = 'standard'
WHERE recommended_mode IS DISTINCT FROM 'standard';
