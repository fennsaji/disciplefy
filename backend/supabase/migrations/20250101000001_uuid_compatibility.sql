-- UUID Compatibility Layer
-- Provides uuid_generate_v4() for Supabase PostgreSQL 17.4
-- This migration ensures compatibility with existing migrations that use uuid_generate_v4()

-- Drop any existing sequences that might cause conflicts on reset
DROP SEQUENCE IF EXISTS purchase_receipt_seq CASCADE;

-- Create uuid_generate_v4() as an alias to gen_random_uuid()
CREATE OR REPLACE FUNCTION uuid_generate_v4()
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT gen_random_uuid();
$$;
