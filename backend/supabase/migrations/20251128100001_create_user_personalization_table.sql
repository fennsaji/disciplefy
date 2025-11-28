-- ============================================================================
-- User Personalization Table
-- ============================================================================
-- Stores user questionnaire responses for personalized topic recommendations
-- Part of the "For You" personalization feature

BEGIN;

-- Create the user_personalization table
CREATE TABLE user_personalization (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Questionnaire responses (stored as enum values for type safety)
  faith_journey TEXT CHECK (faith_journey IN ('new', 'growing', 'mature')),
  seeking TEXT[] DEFAULT '{}', -- Can select multiple: peace, guidance, knowledge, relationships, challenges
  time_commitment TEXT CHECK (time_commitment IN ('5min', '15min', '30min')),

  -- Track questionnaire status
  questionnaire_completed BOOLEAN DEFAULT false,
  questionnaire_skipped BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- One personalization record per user
  CONSTRAINT unique_user_personalization UNIQUE(user_id)
);

-- Create indexes for efficient lookups
CREATE INDEX idx_user_personalization_user_id ON user_personalization(user_id);
CREATE INDEX idx_user_personalization_completed ON user_personalization(questionnaire_completed)
  WHERE questionnaire_completed = true;

-- Enable RLS
ALTER TABLE user_personalization ENABLE ROW LEVEL SECURITY;

-- Users can only read/write their own personalization data
CREATE POLICY "Users can read their own personalization"
  ON user_personalization FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own personalization"
  ON user_personalization FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own personalization"
  ON user_personalization FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role can manage all records
CREATE POLICY "Service role can manage all personalization"
  ON user_personalization FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_personalization_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_personalization_updated_at
  BEFORE UPDATE ON user_personalization
  FOR EACH ROW
  EXECUTE FUNCTION update_user_personalization_updated_at();

-- Add comments for documentation
COMMENT ON TABLE user_personalization IS 'Stores user questionnaire responses for personalized topic recommendations';
COMMENT ON COLUMN user_personalization.faith_journey IS 'User''s self-reported faith journey stage: new, growing, or mature';
COMMENT ON COLUMN user_personalization.seeking IS 'What the user is seeking: peace, guidance, knowledge, relationships, challenges';
COMMENT ON COLUMN user_personalization.time_commitment IS 'Daily time commitment: 5min, 15min, or 30min';
COMMENT ON COLUMN user_personalization.questionnaire_completed IS 'Whether user completed the questionnaire';
COMMENT ON COLUMN user_personalization.questionnaire_skipped IS 'Whether user explicitly skipped the questionnaire';

COMMIT;
