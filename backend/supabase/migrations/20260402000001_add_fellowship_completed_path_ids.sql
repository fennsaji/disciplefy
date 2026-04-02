-- Track historically completed paths per fellowship.
-- Since fellowship_study has UNIQUE(fellowship_id), assigning a new path
-- replaces the row and loses completion history. This column preserves it.
ALTER TABLE fellowship_study
  ADD COLUMN IF NOT EXISTS completed_path_ids UUID[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN fellowship_study.completed_path_ids
  IS 'Accumulates IDs of learning paths this fellowship has fully completed over time';
