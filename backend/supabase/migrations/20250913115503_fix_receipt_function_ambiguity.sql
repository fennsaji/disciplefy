-- Migration: Fix ambiguous year_month reference in generate_receipt_number function
-- Date: September 13, 2025
-- Issue: The generate_receipt_number function has an ambiguous column reference to year_month

CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TEXT AS $$
DECLARE
  receipt_num TEXT;
  current_year_month TEXT;
  sequence_num INTEGER;
BEGIN
  -- Format: DISC-YYYYMM-NNNN (e.g., DISC-202501-0001)
  current_year_month := TO_CHAR(NOW(), 'YYYYMM');

  -- Atomically get next sequence number for this month
  INSERT INTO receipt_counters (year_month, last_seq)
  VALUES (current_year_month, 1)
  ON CONFLICT (year_month) DO UPDATE
  SET
    last_seq = receipt_counters.last_seq + 1,
    updated_at = NOW()
  RETURNING last_seq INTO sequence_num;

  receipt_num := 'DISC-' || current_year_month || '-' || LPAD(sequence_num::TEXT, 4, '0');

  RETURN receipt_num;
END;
$$ LANGUAGE plpgsql;