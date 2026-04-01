-- Fix: Hebrews learning path (aaa00000-0000-0000-0000-000000000030) had total_xp = 0
-- because compute_learning_path_total_xp was never called for it.
-- Paths 1-29 were computed in their respective migrations; paths 31-34 were computed
-- in 20260316000002. Path 30 was added in 20260313000001 but the compute call was missed.

SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000030');
