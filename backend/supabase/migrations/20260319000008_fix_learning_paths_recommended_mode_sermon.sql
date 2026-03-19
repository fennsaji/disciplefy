-- =====================================================
-- Migration: Allow 'sermon' in learning_paths.recommended_mode
-- =====================================================
-- The study engine supports 5 modes (quick/standard/deep/lectio/sermon)
-- but learning_paths.recommended_mode only allowed 4.
-- This aligns the constraint with all other study_mode columns.
-- =====================================================

BEGIN;

ALTER TABLE learning_paths
  DROP CONSTRAINT IF EXISTS learning_paths_recommended_mode_check;

ALTER TABLE learning_paths
  ADD CONSTRAINT learning_paths_recommended_mode_check
  CHECK (recommended_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

COMMENT ON COLUMN learning_paths.recommended_mode IS
  'Suggested study mode for optimal learning (quick/standard/deep/lectio/sermon)';

COMMIT;
