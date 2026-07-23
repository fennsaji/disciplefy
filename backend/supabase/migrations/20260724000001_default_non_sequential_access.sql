-- Make all learning paths non-sequential access by default
-- New paths default to allow_non_sequential_access = true; existing paths updated to true

ALTER TABLE learning_paths
ALTER COLUMN allow_non_sequential_access SET DEFAULT true;

UPDATE learning_paths
SET allow_non_sequential_access = true
WHERE allow_non_sequential_access = false;
