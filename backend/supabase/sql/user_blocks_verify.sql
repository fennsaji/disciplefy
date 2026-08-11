-- Verification for the user_blocks migration. Run against local Supabase only.
-- Exits with an exception on the first failed assertion.

BEGIN;

-- Three throwaway users. auth.users rows are created directly because this
-- script runs against a local database with no auth server involved.
INSERT INTO auth.users (id, instance_id, aud, role, email)
VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'blocker@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'blocked@test.local'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'thirdparty@test.local')
ON CONFLICT (id) DO NOTHING;

-- A throwaway fellowship. fellowship_reports.fellowship_id is a real FK, so a
-- minimal valid fellowships row is required for the content-originated block path.
INSERT INTO fellowships (id, name, mentor_user_id)
VALUES ('00000000-0000-0000-0000-0000000000f1', 'Verify Test Fellowship', '00000000-0000-0000-0000-0000000000a1')
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  v_first BOOLEAN;
  v_second BOOLEAN;
  v_forward INT;
  v_reverse INT;
  v_third BOOLEAN;
  v_fourth BOOLEAN;
  v_fifth BOOLEAN;
  v_report_count INT;
  v_report RECORD;
BEGIN
  -- 1. First block returns true and creates the row.
  v_first := block_user(
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000b2',
    NULL, NULL, NULL, NULL
  );
  IF NOT v_first THEN
    RAISE EXCEPTION 'FAIL: first block_user should return true';
  END IF;

  -- 2. Re-blocking is idempotent and returns false.
  v_second := block_user(
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000b2',
    NULL, NULL, NULL, NULL
  );
  IF v_second THEN
    RAISE EXCEPTION 'FAIL: repeat block_user should return false';
  END IF;

  -- 3. blocked_user_ids sees the block from the blocker's side.
  SELECT COUNT(*) INTO v_forward
  FROM blocked_user_ids('00000000-0000-0000-0000-0000000000a1')
  WHERE user_id = '00000000-0000-0000-0000-0000000000b2';
  IF v_forward <> 1 THEN
    RAISE EXCEPTION 'FAIL: blocker should see blocked user, got % rows', v_forward;
  END IF;

  -- 4. And from the blocked user's side — the block is mutual.
  SELECT COUNT(*) INTO v_reverse
  FROM blocked_user_ids('00000000-0000-0000-0000-0000000000b2')
  WHERE user_id = '00000000-0000-0000-0000-0000000000a1';
  IF v_reverse <> 1 THEN
    RAISE EXCEPTION 'FAIL: block should be mutual, got % rows', v_reverse;
  END IF;

  -- 5. Self-blocks are rejected by the CHECK constraint.
  BEGIN
    INSERT INTO user_blocks (blocker_id, blocked_id)
    VALUES ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1');
    RAISE EXCEPTION 'FAIL: self-block should have been rejected';
  EXCEPTION WHEN check_violation THEN
    NULL; -- expected
  END;

  -- 6. A content-originated block (b2 blocks a1, reported from a post) creates
  -- exactly one fellowship_reports row with the expected shape.
  v_third := block_user(
    '00000000-0000-0000-0000-0000000000b2',
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000f1',
    'post',
    '00000000-0000-0000-0000-0000000000c1',
    'spam'
  );
  IF NOT v_third THEN
    RAISE EXCEPTION 'FAIL: content-originated block_user should return true';
  END IF;

  SELECT COUNT(*) INTO v_report_count
  FROM fellowship_reports
  WHERE reporter_user_id = '00000000-0000-0000-0000-0000000000b2'
    AND content_type = 'post'
    AND content_id = '00000000-0000-0000-0000-0000000000c1';
  IF v_report_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: content-originated block should create exactly one report, got %', v_report_count;
  END IF;

  SELECT * INTO v_report
  FROM fellowship_reports
  WHERE reporter_user_id = '00000000-0000-0000-0000-0000000000b2'
    AND content_type = 'post'
    AND content_id = '00000000-0000-0000-0000-0000000000c1';
  IF v_report.reason <> 'user_blocked' THEN
    RAISE EXCEPTION 'FAIL: report reason should be ''user_blocked'', got %', v_report.reason;
  END IF;
  IF v_report.status <> 'pending' THEN
    RAISE EXCEPTION 'FAIL: report status should be ''pending'', got %', v_report.status;
  END IF;
  IF v_report.fellowship_id <> '00000000-0000-0000-0000-0000000000f1' THEN
    RAISE EXCEPTION 'FAIL: report fellowship_id mismatch, got %', v_report.fellowship_id;
  END IF;

  -- 7. Re-blocking the same pair with the same content args is idempotent on
  -- both the block row AND the report — no second report row is created.
  v_fourth := block_user(
    '00000000-0000-0000-0000-0000000000b2',
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000f1',
    'post',
    '00000000-0000-0000-0000-0000000000c1',
    'spam'
  );
  IF v_fourth THEN
    RAISE EXCEPTION 'FAIL: repeat content-originated block_user should return false';
  END IF;

  SELECT COUNT(*) INTO v_report_count
  FROM fellowship_reports
  WHERE reporter_user_id = '00000000-0000-0000-0000-0000000000b2'
    AND content_type = 'post'
    AND content_id = '00000000-0000-0000-0000-0000000000c1';
  IF v_report_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: repeat block must not create a second report, got % rows', v_report_count;
  END IF;

  -- 8. A block with content_type supplied but content_id NULL creates the
  -- block row but no report (fellowship_reports.content_id is NOT NULL).
  v_fifth := block_user(
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000c3',
    '00000000-0000-0000-0000-0000000000f1',
    'post',
    NULL,
    NULL
  );
  IF NOT v_fifth THEN
    RAISE EXCEPTION 'FAIL: block_user with null content_id should still create the block';
  END IF;

  SELECT COUNT(*) INTO v_report_count
  FROM fellowship_reports
  WHERE reporter_user_id = '00000000-0000-0000-0000-0000000000a1';
  IF v_report_count <> 0 THEN
    RAISE EXCEPTION 'FAIL: block with null content_id must not create a report, got % rows', v_report_count;
  END IF;

  RAISE NOTICE 'PASS: all user_blocks assertions held';
END $$;

ROLLBACK;
