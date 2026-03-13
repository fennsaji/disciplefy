-- =====================================================
-- Migration: Fellowship Invite Short Code
-- Change invite token from UUID to 6-character uppercase alpha code
-- =====================================================

-- Function to generate a 6-character uppercase alphabetic code
CREATE OR REPLACE FUNCTION generate_fellowship_invite_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * 26 + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Alter token column: UUID → TEXT, keeping existing records as UUID strings
ALTER TABLE fellowship_invites ALTER COLUMN token TYPE TEXT USING token::text;
ALTER TABLE fellowship_invites ALTER COLUMN token SET DEFAULT generate_fellowship_invite_code();
