-- Opt-in private contact channels for fellowship mentors.
--
-- A mentor can expose a WhatsApp number and/or an email address to the
-- active members of a specific fellowship, so a member can reach them
-- directly instead of posting publicly. This is per-fellowship, per-mentor
-- opt-in: since a single user can mentor multiple fellowships (fellowship_
-- members rows are per fellowship_id + user_id), the same mentor can choose
-- to expose contact info in one fellowship and keep it hidden in another.
-- There is no fellowship-wide or account-wide toggle — each row carries its
-- own settings.
--
-- The two channels are independent nullable columns rather than a single
-- type+value pair: a mentor may set WhatsApp only, email only, both, or
-- neither, and either channel can be cleared without touching the other.
--
-- This file has not been deployed anywhere yet, so it is written to be safe
-- to run against a fresh database AND against a database that already has
-- the old mentor_contact_type/mentor_contact_value shape applied (idempotent
-- on repeat runs too).

-- Drop the old single-channel shape if present.
ALTER TABLE fellowship_members
  DROP CONSTRAINT IF EXISTS fellowship_members_mentor_contact_value_check;

ALTER TABLE fellowship_members
  DROP COLUMN IF EXISTS mentor_contact_type,
  DROP COLUMN IF EXISTS mentor_contact_value;

-- Add the new independent channel columns.
ALTER TABLE fellowship_members
  ADD COLUMN IF NOT EXISTS mentor_whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS mentor_email TEXT;

ALTER TABLE fellowship_members
  DROP CONSTRAINT IF EXISTS fellowship_members_mentor_whatsapp_check;

ALTER TABLE fellowship_members
  ADD CONSTRAINT fellowship_members_mentor_whatsapp_check
  CHECK (mentor_whatsapp IS NULL OR mentor_whatsapp ~ '^[0-9]{8,15}$');

ALTER TABLE fellowship_members
  DROP CONSTRAINT IF EXISTS fellowship_members_mentor_email_check;

ALTER TABLE fellowship_members
  ADD CONSTRAINT fellowship_members_mentor_email_check
  CHECK (
    mentor_email IS NULL
    OR (
      length(mentor_email) <= 254
      AND mentor_email ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$'
    )
  );

COMMENT ON COLUMN fellowship_members.mentor_whatsapp IS
  'Opt-in WhatsApp number (digits only, no +, 8-15 chars) a mentor exposes to active members of THIS fellowship row. NULL hides it. Independent of mentor_email. Per-fellowship: a mentor of multiple fellowships can set this differently in each. Only meaningful when role = ''mentor'' — enforced in application code, not by a DB CHECK.';

COMMENT ON COLUMN fellowship_members.mentor_email IS
  'Opt-in email address (lowercased, max 254 chars) a mentor exposes to active members of THIS fellowship row. NULL hides it. Independent of mentor_whatsapp. Per-fellowship: a mentor of multiple fellowships can set this differently in each. Only meaningful when role = ''mentor'' — enforced in application code, not by a DB CHECK.';
